"""记忆 upsert / 删除 / 增量拉取业务逻辑（TECH_DESIGN §7.2 / §13）。

核心语义：
- 幂等 upsert：主键 = {id}（客户端 UUID）；updated_at 相同或更旧不覆盖。
- server_version：该用户 max(server_version)+1，同一事务内自增。
- 每次写插一行 change_log 审计；GET ?since= 以 change_log.seq 做增量游标。
- tag_ids 对 memory_tags 做 diff（缺的插入/复活，多的墓碑）。
- 删除写 deleted_at 墓碑，不物理删行。
"""

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import AppError, ErrorCode
from app.models.base import utcnow
from app.models.change_log import ChangeAction, ChangeEntity, ChangeLog
from app.models.memory import Memory
from app.models.memory_tag import MemoryTag
from app.models.tag import Tag
from app.repositories.change_log_repository import insert_log, next_server_version
from app.schemas.memory import (
    MemoryItem,
    MemoryListResponse,
    MemoryUpsertRequest,
    MemoryUpsertResponse,
)

logger = logging.getLogger(__name__)


def _dt_to_epoch_ms(dt: datetime) -> int:
    """datetime → epoch 毫秒；SQLite 读出的可能是 naive，按 UTC 处理。"""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp() * 1000)


def _ms_to_dt(ms: int) -> datetime:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


def _deleted_at_dt(ms: int | None) -> datetime | None:
    """把请求里的 deleted_at(epoch 毫秒) 转 datetime。

    0 与 None 一律按「未删除」处理：Swagger 对可选 int 会默认填 0，
    若把 0 当成真实时间会误判为「在 epoch 0 被删除」。
    """
    if ms is None or ms == 0:
        return None
    return _ms_to_dt(ms)


def _dt_eq(a: datetime | None, b: datetime | None) -> bool:
    """比较两个可空 datetime；None 与 None 相等，按 epoch 毫秒对齐（兼容 SQLite naive）。"""
    if (a is None) != (b is None):
        return False
    if a is None:
        return True
    return _dt_to_epoch_ms(a) == _dt_to_epoch_ms(b)


def _to_item(memory: Memory, tag_ids: list[uuid.UUID]) -> MemoryItem:
    return MemoryItem(
        id=memory.id,
        type=memory.type.value,
        title=memory.title,
        text_content=memory.text_content,
        audio_object_key=memory.audio_object_key,
        audio_duration_ms=memory.audio_duration_ms,
        audio_format=memory.audio_format,
        audio_size_bytes=memory.audio_size_bytes,
        source=memory.source.value,
        record_status=memory.record_status.value,
        client_version=memory.client_version,
        created_at=_dt_to_epoch_ms(memory.created_at),
        updated_at=_dt_to_epoch_ms(memory.updated_at),
        deleted_at=_dt_to_epoch_ms(memory.deleted_at) if memory.deleted_at else None,
        server_version=memory.server_version,
        tag_ids=tag_ids,
    )


def _get_memory_or_403(db: Session, memory_id: uuid.UUID, user_id: uuid.UUID) -> Memory | None:
    """按 id 取记忆；存在但属于他人 → AUTH_005；不存在 → None。"""
    memory = db.get(Memory, memory_id)
    if memory is not None and memory.user_id != user_id:
        raise AppError(ErrorCode.AUTH_005, "无权访问该资源", 403)
    return memory


def _active_tag_ids(db: Session, memory_id: uuid.UUID) -> list[uuid.UUID]:
    rows = db.scalars(
        select(MemoryTag.tag_id).where(
            MemoryTag.memory_id == memory_id,
            MemoryTag.deleted_at.is_(None),
        )
    ).all()
    return list(rows)


def _filter_valid_tags(
    db: Session,
    user_id: uuid.UUID,
    incoming: set[uuid.UUID],
) -> set[uuid.UUID]:
    """只保留「存在 + 属于该用户 + 未软删」的标签，其余跳过并 warning。

    为什么容错而不是拒绝请求（写进代码，防后人改坏）：
    tag_ids 每次 PUT 都携带该记忆的**全量**集合。客户端可能引用一个「尚未同步到
    服务端的标签」，若因此拒绝整条 PUT（4xx），这条记忆会永远同步不上去，
    客户端按 E14/E17 无限退避重试 → 死循环。容错跳过则系统收敛：
    标签一旦同步上来，下一次 PUT 会自动补建关联，不丢数据（本地优先原则）。
    """
    if not incoming:
        return set()
    valid = set(
        db.scalars(
            select(Tag.id).where(
                Tag.id.in_(incoming),
                Tag.user_id == user_id,
                Tag.deleted_at.is_(None),
            )
        ).all()
    )
    skipped = incoming - valid
    if skipped:
        logger.warning(
            "记忆 upsert：跳过 %d 个未就绪标签（不存在/非本用户/已删除），id=%s",
            len(skipped),
            sorted(str(t) for t in skipped),
        )
    return valid


def _diff_memory_tags(
    db: Session,
    memory_id: uuid.UUID,
    incoming: set[uuid.UUID],
    server_version: int,
) -> None:
    """对 memory_tags 做 diff：缺的插入/复活，多的墓碑。"""
    now = utcnow()
    existing = set(_active_tag_ids(db, memory_id))
    to_add = incoming - existing
    to_remove = existing - incoming

    for tag_id in to_add:
        row = db.get(MemoryTag, (memory_id, tag_id))
        if row is None:
            db.add(
                MemoryTag(
                    memory_id=memory_id,
                    tag_id=tag_id,
                    created_at=now,
                    updated_at=now,
                    deleted_at=None,
                    server_version=server_version,
                )
            )
        else:
            # 之前墓碑的关联被重新挂上 → 复活
            row.deleted_at = None
            row.updated_at = now
            row.server_version = server_version

    for tag_id in to_remove:
        row = db.get(MemoryTag, (memory_id, tag_id))
        if row is not None:
            row.deleted_at = now
            row.updated_at = now
            row.server_version = server_version


def _content_differs(
    db: Session,
    memory: Memory,
    user_id: uuid.UUID,
    payload: MemoryUpsertRequest,
) -> bool:
    """判断「请求内容」与「库中内容」是否不同（供 unchanged 分支区分真重放/静默丢弃）。

    只回答「内容变没变」，不改变写入判定：是否覆盖仍严格由 updated_at 的 LWW 决定。
    比较范围：10 个标量 + deleted_at(归一化后) + tag_ids(过滤后 vs 现有活跃)。
    """
    if payload.type != memory.type:
        return True
    if payload.title != memory.title:
        return True
    if payload.text_content != memory.text_content:
        return True
    if payload.audio_object_key != memory.audio_object_key:
        return True
    if payload.audio_duration_ms != memory.audio_duration_ms:
        return True
    if payload.audio_format != memory.audio_format:
        return True
    if payload.audio_size_bytes != memory.audio_size_bytes:
        return True
    if payload.source != memory.source:
        return True
    if payload.record_status != memory.record_status:
        return True
    if payload.client_version != memory.client_version:
        return True
    # deleted_at 先归一化（0/None 都算未删除）再比
    if not _dt_eq(_deleted_at_dt(payload.deleted_at), memory.deleted_at):
        return True
    # tag_ids：请求侧过滤成有效标签，与库中现有活跃关联比较
    requested_tags = _filter_valid_tags(db, user_id, set(payload.tag_ids))
    if requested_tags != set(_active_tag_ids(db, memory.id)):
        return True
    return False


def upsert_memory(
    db: Session,
    user_id: uuid.UUID,
    memory_id: uuid.UUID,
    payload: MemoryUpsertRequest,
) -> MemoryUpsertResponse:
    """幂等 upsert（AC-K6）。"""
    memory = _get_memory_or_403(db, memory_id, user_id)
    incoming_updated_at = payload.updated_at

    if memory is None:
        # 不存在 → 新建；未就绪标签（不存在/非本用户/已删除）跳过，不阻断记忆本身写入
        valid_tag_ids = _filter_valid_tags(db, user_id, set(payload.tag_ids))
        new_sv = next_server_version(db, user_id)
        memory = Memory(
            id=memory_id,
            user_id=user_id,
            type=payload.type,
            title=payload.title,
            text_content=payload.text_content,
            audio_object_key=payload.audio_object_key,
            audio_duration_ms=payload.audio_duration_ms,
            audio_format=payload.audio_format,
            audio_size_bytes=payload.audio_size_bytes,
            source=payload.source,
            record_status=payload.record_status,
            client_version=payload.client_version,
            created_at=_ms_to_dt(payload.created_at),
            updated_at=_ms_to_dt(payload.updated_at),
            deleted_at=_deleted_at_dt(payload.deleted_at),
            server_version=new_sv,
        )
        db.add(memory)
        db.flush()
        _diff_memory_tags(db, memory_id, valid_tag_ids, new_sv)
        insert_log(db, user_id, ChangeEntity.memory, memory_id, ChangeAction.upsert, new_sv)
        db.commit()
        return MemoryUpsertResponse(id=memory_id, server_version=new_sv, status="upserted")

    # 已存在：updated_at 相同或更旧 → 不覆盖（幂等命中 / LWW：较新者胜）
    #
    # 为什么 LWW 不覆盖：updated_at 较新者胜是同步冲突的既定契约（§13.2），不要改，
    #   否则会把「服务端更新的版本」退回成客户端的旧版本。
    # 为什么必须回传 content_differs：LWW 下「客户端改了内容但没能增大 updated_at」
    #   （离线写、时钟回拨、忘改时间戳等）会被静默丢弃——客户端只看到 200 以为同步成功，
    #   这是最贵的「HTTP 200 但改动消失」。回传该标记让客户端能识别并重推，避免静默丢数据。
    if incoming_updated_at <= _dt_to_epoch_ms(memory.updated_at):
        differs = _content_differs(db, memory, user_id, payload)
        if differs:
            logger.warning(
                "记忆 upsert：客户端内容已变更但 updated_at 未增大，本次未写入 "
                "(memory_id=%s, client_updated_at=%s, server_updated_at=%s, server_version=%s)",
                memory_id,
                incoming_updated_at,
                _dt_to_epoch_ms(memory.updated_at),
                memory.server_version,
            )
        # 无论内容是否不同，都不写库、不插 change_log、不递增 server_version
        return MemoryUpsertResponse(
            id=memory_id,
            server_version=memory.server_version,
            status="unchanged",
            content_differs=differs,
        )

    # 更新 → 覆盖并 server_version + 1
    valid_tag_ids = _filter_valid_tags(db, user_id, set(payload.tag_ids))
    new_sv = next_server_version(db, user_id)
    memory.type = payload.type
    memory.title = payload.title
    memory.text_content = payload.text_content
    memory.audio_object_key = payload.audio_object_key
    memory.audio_duration_ms = payload.audio_duration_ms
    memory.audio_format = payload.audio_format
    memory.audio_size_bytes = payload.audio_size_bytes
    memory.source = payload.source
    memory.record_status = payload.record_status
    memory.client_version = payload.client_version
    memory.updated_at = _ms_to_dt(payload.updated_at)
    memory.deleted_at = _deleted_at_dt(payload.deleted_at)
    memory.server_version = new_sv
    # created_at 保持原始创建时间不变
    _diff_memory_tags(db, memory_id, valid_tag_ids, new_sv)
    insert_log(db, user_id, ChangeEntity.memory, memory_id, ChangeAction.upsert, new_sv)
    db.commit()
    return MemoryUpsertResponse(id=memory_id, server_version=new_sv, status="upserted")


def delete_memory(db: Session, user_id: uuid.UUID, memory_id: uuid.UUID) -> dict:
    """逻辑删除（墓碑）；幂等：已删除再删同样返回 200。"""
    memory = _get_memory_or_403(db, memory_id, user_id)
    if memory is None:
        raise AppError(ErrorCode.NOTFOUND_001, "资源不存在", 404)

    if memory.deleted_at is not None:
        # 幂等命中：不重复写墓碑、不重复审计
        return {"id": memory_id, "server_version": memory.server_version, "status": "deleted"}

    new_sv = next_server_version(db, user_id)
    memory.deleted_at = utcnow()
    memory.server_version = new_sv
    insert_log(db, user_id, ChangeEntity.memory, memory_id, ChangeAction.delete, new_sv)
    db.commit()
    return {"id": memory_id, "server_version": new_sv, "status": "deleted"}


def list_memories(db: Session, user_id: uuid.UUID, since: int, limit: int) -> MemoryListResponse:
    """增量拉取：以 change_log 为游标，返回含墓碑的记忆条目。"""
    entries = db.scalars(
        select(ChangeLog)
        .where(
            ChangeLog.user_id == user_id,
            ChangeLog.entity == ChangeEntity.memory,
            ChangeLog.seq > since,
        )
        .order_by(ChangeLog.seq.asc())
        .limit(limit + 1)
    ).all()

    has_more = len(entries) > limit
    entries = entries[:limit]

    ids = [e.entity_id for e in entries]
    memories: dict[uuid.UUID, Memory] = {}
    tags_map: dict[uuid.UUID, list[uuid.UUID]] = {}
    if ids:
        for m in db.scalars(
            select(Memory).where(Memory.id.in_(ids), Memory.user_id == user_id)
        ).all():
            memories[m.id] = m
        for t in db.scalars(
            select(MemoryTag).where(
                MemoryTag.memory_id.in_(ids),
                MemoryTag.deleted_at.is_(None),
            )
        ).all():
            tags_map.setdefault(t.memory_id, []).append(t.tag_id)

    items = [
        _to_item(memories[e.entity_id], tags_map.get(e.entity_id, []))
        for e in entries
        if e.entity_id in memories
    ]

    next_cursor = entries[-1].seq if entries else since
    return MemoryListResponse(items=items, next_cursor=next_cursor, has_more=has_more)
