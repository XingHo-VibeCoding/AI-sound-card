"""离线验证：未捕获异常只记一条日志、返回 SRV_001、且不再向外抛。

背景：FastAPI 的 ServerErrorMiddleware 在处理器返回响应后**仍会 re-raise**，
导致日志出现「未捕获异常」+「ERROR: Exception in ASGI application」两条。
本脚本用一个抛异常的临时路由（仅测试用，不进生产代码）验证：
ErrorHandlingMiddleware 捕获后返回 500 且不向外抛，日志只有一条。

运行：./.venv/Scripts/python.exe scripts/verify_error_middleware.py
"""

import asyncio
import json
import logging
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from fastapi import FastAPI  # noqa: E402

from app.core.handlers import register_exception_handlers  # noqa: E402
from app.core.middleware import ErrorHandlingMiddleware, TraceMiddleware  # noqa: E402


def build_app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(ErrorHandlingMiddleware)
    app.add_middleware(TraceMiddleware)
    register_exception_handlers(app)

    @app.get("/boom")
    def boom():
        raise RuntimeError("模拟未捕获异常")

    return app


async def drive(app, path):
    scope = {
        "type": "http",
        "http_version": "1.1",
        "method": "GET",
        "path": path,
        "raw_path": path.encode(),
        "query_string": b"",
        "headers": [],
        "scheme": "http",
        "server": ("test", 80),
        "client": ("test", 12345),
    }
    messages = []

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    raised = None
    try:
        await app(scope, receive, send)
    except Exception as exc:  # noqa: BLE001
        raised = exc
    return messages, raised


class Capture(logging.Handler):
    def __init__(self):
        super().__init__()
        self.records = []

    def emit(self, record):
        self.records.append(record)


async def main() -> None:
    app = build_app()
    capture = Capture()
    root = logging.getLogger()
    root.addHandler(capture)
    root.setLevel(logging.DEBUG)

    messages, raised = await drive(app, "/boom")

    start = next(m for m in messages if m["type"] == "http.response.start")
    body = b"".join(m.get("body", b"") for m in messages if m["type"] == "http.response.body")
    parsed = json.loads(body.decode("utf-8"))

    print("status:", start["status"])
    print("body:", json.dumps(parsed, ensure_ascii=False))
    print("propagated_to_asgi:", raised is not None)
    print("log_record_count:", len(capture.records))
    for r in capture.records:
        print("  LOG:", r.levelname, "|", r.getMessage())

    ok = (
        start["status"] == 500
        and parsed["error"]["code"] == "SRV_001"
        and raised is None
        and len(capture.records) == 1
    )
    print("RESULT:", "PASS" if ok else "FAIL")
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
