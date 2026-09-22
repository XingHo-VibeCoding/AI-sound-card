"""最小复现：PUT 未增大 updated_at 时不再静默丢内容（回传 content_differs）。

三步严格对应缺陷报告的复现（前置：服务已起在 127.0.0.1:8000）：
  1) 首次 PUT：标题 A、updated_at=T1   → 200 upserted,  DB 标题 = A
  2) 再 PUT  ：标题 B、updated_at 仍 T1 → 200 unchanged + content_differs=True, DB 仍 = A
                                          （改动未落库，但客户端被明确告知「内容确实不同」）
  3) 再 PUT  ：标题 B、updated_at=T2>T1 → 200 upserted,  DB 标题 = B（LWW 协议本身正常）

运行：./.venv/Scripts/python.exe scripts/repro_content_differs.py
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.models import Memory  # noqa: E402

BASE = "http://127.0.0.1:8000/api/v1"
DB = create_engine("sqlite:///./dev.db", connect_args={"timeout": 30})


def call(method, path, body=None, token=None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def db_title(mid: str) -> str:
    with Session(DB) as db:
        row = db.get(Memory, uuid.UUID(mid))
        return row.title if row else "<不存在>"


def main() -> None:
    uname = f"cd{int(time.time())}"
    _, reg = call("POST", "/auth/register", {"username": uname, "password": "secret123"})
    tok = reg["access_token"]

    mid = str(uuid.uuid4())
    t1 = int(time.time() * 1000)
    base = {
        "type": "text", "title": "A", "text_content": None,
        "audio_object_key": None, "audio_duration_ms": None, "audio_format": None,
        "audio_size_bytes": None, "source": "quick_note", "record_status": "normal",
        "created_at": t1, "updated_at": t1, "deleted_at": None,
        "client_version": "1.0.0", "tag_ids": [],
    }

    print("memory_id:", mid)
    st, r = call("PUT", f"/memories/{mid}", base, tok)
    print(f"1) 首次 PUT 标题A updated_at=T1 -> HTTP {st} {r};  DB 标题={db_title(mid)}")

    st, r = call("PUT", f"/memories/{mid}", {**base, "title": "B"}, tok)
    print(f"2) 改标题B updated_at 仍 T1    -> HTTP {st} {r};  DB 标题={db_title(mid)} (期望仍是 A，且 content_differs=true)")

    st, r = call("PUT", f"/memories/{mid}", {**base, "title": "B", "updated_at": t1 + 1}, tok)
    print(f"3) 改标题B updated_at=T2>T1    -> HTTP {st} {r};  DB 标题={db_title(mid)} (期望 B)")


if __name__ == "__main__":
    main()
