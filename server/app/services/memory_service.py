"""记忆 upsert / 删除 / 增量拉取业务逻辑（TECH_DESIGN §7.2 / §13）。

核心语义：
- 幂等 upsert：主键 = {id}（客户端 UUID）；updated_at 相同或更旧不覆盖。
- server_version：该用户 max(server_version)+1，同一事务内自增。
- 每次写插一行 change_log 审计；GET ?since= 以 change_log.seq 做增量游标。
- tag_ids 对 memory_tags 做 diff（缺的插入/复活，多的墓碑）。
- 删除写 deleted_at 墓碑，不物理删行。
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import AppError, ErrorCode
from app.models.base import utcnow
from app.models.change_log import ChangeAction, ChangeEntity, ChangeLog
from app.models.memory import Memory
from app.models.memory_tag import MemoryTag
from app.repositories.change_log_repository import insert_log, next_server_version
from app.schemas.memory import (
    MemoryItem,
    MemoryListResponse,
    MemoryUpsertRequest,
    MemoryUpsertResponse,
)


def _dt_to_epoch_ms(dt: datetime) -> int:
    """datetime → epoch 毫秒；SQLite 读出的可能是 naive，按 UTC 处理。"""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp() * 1000)


def _ms_to_dt(ms: int) -> datetime:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


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
        # 不存在 → 新建
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
            deleted_at=_ms_to_dt(payload.deleted_at) if payload.deleted_at else None,
            server_version=new_sv,
        )
        db.add(memory)
        db.flush()
        _diff_memory_tags(db, memory_id, set(payload.tag_ids), new_sv)
        insert_log(db, user_id, ChangeEntity.memory, memory_id, ChangeAction.upsert, new_sv)
        db.commit()
        return MemoryUpsertResponse(id=memory_id, server_version=new_sv, status="upserted")

    # 已存在：updated_at 相同或更旧 → 不覆盖（幂等命中）
    if incoming_updated_at <= _dt_to_epoch_ms(memory.updated_at):
        return MemoryUpsertResponse(
            id=memory_id,
            server_version=memory.server_version,
            status="unchanged",
        )

    # 更新 → 覆盖并 server_version + 1
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
    memory.deleted_at = _ms_to_dt(payload.deleted_at) if payload.deleted_at else None
    memory.server_version = new_sv
    # created_at 保持原始创建时间不变
    _diff_memory_tags(db, memory_id, set(payload.tag_ids), new_sv)
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
