"""闭环六接口实测脚本（可入库，重复运行安全）。

前置：服务已起在 http://127.0.0.1:8000（uvicorn app.main:app）。
运行：./.venv/Scripts/python.exe scripts/e2e_test.py

每一步打印实际 HTTP 状态码与响应体；末尾做数据库侧墓碑 / 审计断言。
注意：change_log.seq 是全局自增，增量游标断言用实际 seq 值（不硬编码）。
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

# 保证从任意目录运行都能导入 server/app 包
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


class _Tee:
    """同时写 stdout 与 UTF-8 结果文件，避免 PowerShell 管道乱码。"""

    def __init__(self, path: str):
        self._file = open(path, "w", encoding="utf-8")  # noqa: SIM115

    def write(self, s: str) -> None:
        sys.__stdout__.write(s)
        self._file.write(s)

    def flush(self) -> None:
        sys.__stdout__.flush()
        self._file.flush()


sys.stdout = _Tee(os.path.join(os.path.dirname(os.path.abspath(__file__)), "e2e_result.txt"))

BASE = "http://127.0.0.1:8000/api/v1"

# ---- DB 直连（仅用于标签预置、墓碑断言、审计计数，不经过服务端接口）----
from sqlalchemy import create_engine, func, select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.models import ChangeLog, Memory, MemoryTag, Tag  # noqa: E402
from app.models.base import utcnow  # noqa: E402

DB_ENGINE = create_engine("sqlite:///./dev.db", connect_args={"timeout": 30})


def call(method: str, path: str, body=None, token: str | None = None):
    url = BASE + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = raw
        return e.code, parsed


def _redact(obj):
    """递归隐藏 token 值，避免把 JWT 写进日志/报告。"""
    if isinstance(obj, dict):
        return {k: ("<redacted>" if "token" in k.lower() else _redact(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_redact(v) for v in obj]
    return obj


def show(label: str, status: int, body):
    print(f"[{label}] HTTP {status}")
    print("   " + json.dumps(_redact(body), ensure_ascii=False, default=str))
    return status, body


def check(label: str, cond: bool):
    print(f"   ==> {'PASS' if cond else 'FAIL'}: {label}")
    if not cond:
        raise SystemExit(f"FAILED: {label}")


def user_memory_seqs(user_id: str) -> list[int]:
    """该用户 entity=memory 的 change_log seq 升序列表。"""
    with Session(DB_ENGINE) as db:
        return list(
            db.scalars(
                select(ChangeLog.seq)
                .where(ChangeLog.user_id == uuid.UUID(user_id), ChangeLog.entity == "memory")
                .order_by(ChangeLog.seq.asc())
            ).all()
        )


def main() -> None:
    uname = f"u{int(time.time())}"  # 每次运行唯一用户名，保证可重复执行
    password = "secret123"
    memory_id = str(uuid.uuid4())

    print("=" * 70)
    print("闭环六接口实测")
    print("=" * 70)

    # 1. 注册
    st, body = show("1. 注册", *call("POST", "/auth/register", {"username": uname, "password": password, "nickname": "测试"}))
    check("注册返回 201", st == 201)
    check("拿到双 token 与 user", body.get("access_token") and body.get("refresh_token") and body.get("user"))
    access = body["access_token"]
    refresh = body["refresh_token"]
    user_id = body["user"]["id"]

    # 2. 重复注册同名
    st, body = show("2. 重复注册同名", *call("POST", "/auth/register", {"username": uname, "password": password}))
    check("返回 409", st == 409)
    check("错误码 AUTH_001", body.get("error", {}).get("code") == "AUTH_001")

    # 3. 错密码登录
    st, body = show("3. 错密码登录", *call("POST", "/auth/login", {"username": uname, "password": "wrong-pass"}))
    check("返回 401", st == 401)
    check("错误码 AUTH_002", body.get("error", {}).get("code") == "AUTH_002")

    # 4. 正确登录
    st, body = show("4. 正确登录", *call("POST", "/auth/login", {"username": uname, "password": password}))
    check("返回 200 + 双 token", st == 200 and body.get("access_token") and body.get("refresh_token"))

    # 5. 不带 token 调 /me
    st, body = show("5. 不带 token 调 /me", *call("GET", "/me"))
    check("返回 401", st == 401)
    check("错误码 AUTH_003", body.get("error", {}).get("code") == "AUTH_003")

    # 6. 带 token 调 /me
    st, body = show("6. 带 token 调 /me", *call("GET", "/me", token=access))
    check("返回 200 且用户名一致", st == 200 and body.get("username") == uname)

    # 预置两个标签（tags 接口不在本期范围，直接入库作为 fixture；不进 change_log）
    tag_a = str(uuid.uuid4())
    tag_b = str(uuid.uuid4())
    with Session(DB_ENGINE) as db:
        for tid in (tag_a, tag_b):
            db.add(Tag(id=uuid.UUID(tid), user_id=uuid.UUID(user_id), name=tid[:6], color=None,
                       created_at=utcnow(), updated_at=utcnow(), deleted_at=None, server_version=0))
        db.commit()
    print(f"[预置] 直接入库 2 个标签（fixture，不进 change_log）: {tag_a[:8]}... {tag_b[:8]}...")

    # 基础记忆请求体（created_at / updated_at 用固定毫秒，便于原样重放）
    base_ts = int(time.time() * 1000)
    mem_body = {
        "type": "text",
        "title": "首条记忆",
        "text_content": "hello",
        "audio_object_key": None,
        "audio_duration_ms": None,
        "audio_format": None,
        "audio_size_bytes": None,
        "source": "quick_note",
        "record_status": "normal",
        "created_at": base_ts,
        "updated_at": base_ts,
        "deleted_at": None,
        "client_version": "1.0.0",
        "tag_ids": [],
    }

    # 7. 首次 PUT（新建）
    st, body = show("7. PUT 记忆（首次新建）", *call("PUT", f"/memories/{memory_id}", mem_body, token=access))
    check("status == upserted", body.get("status") == "upserted")
    check("server_version == 1", body.get("server_version") == 1)

    # 8. 原样重放（幂等）
    st, body = show("8. 原样重放（幂等）", *call("PUT", f"/memories/{memory_id}", mem_body, token=access))
    check("status == unchanged", body.get("status") == "unchanged")
    check("server_version 保持 1", body.get("server_version") == 1)

    # 9. 带更新 updated_at + tag_ids 再 PUT
    mem_body2 = dict(mem_body, updated_at=base_ts + 1000, tag_ids=[tag_a, tag_b])
    st, body = show("9. 带更新 updated_at + tag_ids 再 PUT", *call("PUT", f"/memories/{memory_id}", mem_body2, token=access))
    check("status == upserted", body.get("status") == "upserted")
    check("server_version == 2", body.get("server_version") == 2)

    # 10. 取该用户实际 change_log seq（全局自增，用于增量游标断言）
    s1, s2 = user_memory_seqs(user_id)
    check("该用户已有 2 条 memory 审计", len(user_memory_seqs(user_id)) == 2)

    # 10a. GET /memories?since=s1-1&limit=1 → 增量第一页
    st, body = show(f"10a. GET /memories?since={s1 - 1}&limit=1", *call("GET", f"/memories?since={s1 - 1}&limit=1", token=access))
    check("返回 200", st == 200)
    check(f"next_cursor == {s1}", body.get("next_cursor") == s1)
    check("has_more == True", body.get("has_more") is True)
    first_item = body.get("items", [{}])[0]
    check("首条 id 匹配", str(first_item.get("id")) == memory_id)

    # 10b. GET /memories?since=s1 → 增量第二页（应含 tag_ids）
    st, body = show(f"10b. GET /memories?since={s1}", *call("GET", f"/memories?since={s1}", token=access))
    check("返回 200", st == 200)
    items = body.get("items", [])
    check(f"next_cursor == {s2}", body.get("next_cursor") == s2)
    check("has_more == False", body.get("has_more") is False)
    mem_item = next((i for i in items if str(i.get("id")) == memory_id), None)
    check("看到该条", mem_item is not None)
    check("server_version == 2", mem_item and mem_item.get("server_version") == 2)
    check("tag_ids 正确", mem_item and set(mem_item.get("tag_ids", [])) == {tag_a, tag_b})

    # 11. DELETE（墓碑）
    st, body = show("11. DELETE 记忆", *call("DELETE", f"/memories/{memory_id}", token=access))
    check("status == deleted", body.get("status") == "deleted")
    check("server_version == 3", body.get("server_version") == 3)

    # 12. 回查数据库：行仍在、deleted_at 非空（墓碑证据）+ change_log 计数
    s3 = user_memory_seqs(user_id)[-1]
    with Session(DB_ENGINE) as db:
        row = db.get(Memory, uuid.UUID(memory_id))
        log_count = db.scalar(select(func.count()).select_from(ChangeLog).where(ChangeLog.user_id == uuid.UUID(user_id)))
        print(f"[12. 回查 DB] memory 行存在={row is not None}, deleted_at={row.deleted_at if row else None}")
        print(f"[12. 回查 DB] change_log 行数（该用户）={log_count}")
        check("DB 行仍存在", row is not None)
        check("deleted_at 非空", row is not None and row.deleted_at is not None)
        check("change_log 审计在写（== 3）", log_count == 3)

    # 13. GET /memories?since=s2 → 应返回墓碑项（deleted_at 非空）
    st, body = show(f"13. GET /memories?since={s2}（应返回墓碑）", *call("GET", f"/memories?since={s2}", token=access))
    check("返回 200", st == 200)
    check(f"next_cursor == {s3}", body.get("next_cursor") == s3)
    items = body.get("items", [])
    tomb = next((i for i in items if str(i.get("id")) == memory_id), None)
    check("返回墓碑项且 deleted_at 非空", tomb is not None and tomb.get("deleted_at") is not None)

    # 14. 越权隔离：换一个用户访问该记忆 → 403 AUTH_005
    st, body = show("14. 越权访问（换用户）", *call("PUT", f"/memories/{memory_id}", mem_body2, token=_other_user_access()))
    check("返回 403 AUTH_005", st == 403 and body.get("error", {}).get("code") == "AUTH_005")

    # 15. refresh 换发 access_token（正向验证）
    st, body = show("15. 刷新 access_token", *call("POST", "/auth/refresh", {"refresh_token": refresh}))
    check("返回 200 且带新 access_token", st == 200 and bool(body.get("access_token")))

    # 16. 回归 P0：tag_ids 含「不存在的标签」→ 不 500，记忆照常写入（标签容错）
    ghost_tag = str(uuid.uuid4())
    ghost_mem_id = str(uuid.uuid4())
    ghost_body = dict(mem_body, created_at=base_ts + 2000, updated_at=base_ts + 2000, tag_ids=[ghost_tag])
    st, body = show("16. PUT 记忆（tag_ids 含不存在的标签）", *call("PUT", f"/memories/{ghost_mem_id}", ghost_body, token=access))
    check("不报 500，返回 200", st == 200)
    check("status == upserted", body.get("status") == "upserted")
    with Session(DB_ENGINE) as db:
        ghost_mem = db.get(Memory, uuid.UUID(ghost_mem_id))
        ghost_links = db.scalars(select(MemoryTag).where(MemoryTag.memory_id == uuid.UUID(ghost_mem_id))).all()
        check("记忆本身写进去了", ghost_mem is not None)
        check("没有写入任何 memory_tags 行", len(ghost_links) == 0)

    # 17. 回归：deleted_at == 0 按「未删除」处理（Swagger 可选 int 默认填 0）
    zero_mem_id = str(uuid.uuid4())
    zero_body = dict(mem_body, created_at=base_ts + 3000, updated_at=base_ts + 3000, deleted_at=0, tag_ids=[])
    st, body = show("17. PUT 记忆（deleted_at=0 应视为未删除）", *call("PUT", f"/memories/{zero_mem_id}", zero_body, token=access))
    check("返回 200 且 upserted", st == 200 and body.get("status") == "upserted")
    with Session(DB_ENGINE) as db:
        zero_mem = db.get(Memory, uuid.UUID(zero_mem_id))
        check("deleted_at 视为 None（未墓碑）", zero_mem is not None and zero_mem.deleted_at is None)

    # 18. 回归 P1：同 id 改内容但 updated_at 未增大 → unchanged 且 content_differs=True，库内不落改
    cd_mem_id = str(uuid.uuid4())
    cd_ts = base_ts + 5000
    cd_v1 = dict(mem_body, title="原标题", text_content="v1", created_at=cd_ts, updated_at=cd_ts, tag_ids=[])
    st, body = show("18. PUT 记忆（原标题, updated_at=T1）", *call("PUT", f"/memories/{cd_mem_id}", cd_v1, token=access))
    check("首次 upserted", st == 200 and body.get("status") == "upserted")
    check("upserted 时 content_differs 缺省为 False", body.get("content_differs") is False)

    cd_v2 = dict(cd_v1, title="被改的标题", text_content="v2")  # updated_at 仍为 T1
    st, body = show("18. 改内容但 updated_at 不变 → 应 unchanged + content_differs=True", *call("PUT", f"/memories/{cd_mem_id}", cd_v2, token=access))
    check("返回 200", st == 200)
    check("status == unchanged", body.get("status") == "unchanged")
    check("content_differs == True", body.get("content_differs") is True)
    with Session(DB_ENGINE) as db:
        cd_row = db.get(Memory, uuid.UUID(cd_mem_id))
        check("库中标题仍是旧值（改动未落库）", cd_row is not None and cd_row.title == "原标题")

    # 19. 回归：同 id 原样重发 → unchanged 且 content_differs=False（真重放，不打日志）
    st, body = show("19. 同 id 原样重发 → 应 unchanged + content_differs=False", *call("PUT", f"/memories/{cd_mem_id}", cd_v1, token=access))
    check("返回 200", st == 200)
    check("status == unchanged", body.get("status") == "unchanged")
    check("content_differs == False", body.get("content_differs") is False)

    print("=" * 70)
    print("全部通过")
    print("=" * 70)


def _other_user_access() -> str:
    """注册另一个用户并返回其 access_token，用于跨账号隔离测试。"""
    uname = f"other{int(time.time() * 1000)}"
    st, body = call("POST", "/auth/register", {"username": uname, "password": "secret123"})
    return body.get("access_token", "")


if __name__ == "__main__":
    main()
