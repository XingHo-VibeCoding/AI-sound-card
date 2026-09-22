"""请求级中间件：trace_id 贯通 + 未捕获异常兜底（TECH_DESIGN §9.5）。"""

import logging

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.exceptions import ErrorCode, build_error_body, get_request_trace_id, new_trace_id

logger = logging.getLogger(__name__)


class TraceMiddleware(BaseHTTPMiddleware):
    """从 X-Trace-Id 透传 trace_id，否则生成；回写响应头。"""

    async def dispatch(self, request: Request, call_next):
        trace_id = request.headers.get("X-Trace-Id") or new_trace_id()
        request.state.trace_id = trace_id
        response = await call_next(request)
        response.headers["X-Trace-Id"] = trace_id
        return response


class ErrorHandlingMiddleware:
    """兜底未捕获异常：返回统一 SRV_001 错误体，且**不再向外抛**。

    纯 ASGI 中间件（非 BaseHTTPMiddleware）：在 ServerErrorMiddleware 内侧捕获异常，
    返回响应后即中止传播，避免 Starlette 再抛一次导致日志重复
    （「未捕获异常」+「ERROR: Exception in ASGI application」两条）。
    """

    def __init__(self, app) -> None:  # noqa: ANN001
        self.app = app

    async def __call__(self, scope, receive, send) -> None:  # noqa: ANN001
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        response_started = False

        async def wrapped_send(message) -> None:  # noqa: ANN001
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, receive, wrapped_send)
        except Exception as exc:  # noqa: BLE001
            trace_id = get_request_trace_id(Request(scope))
            logger.exception("未捕获异常 [trace_id=%s]: %s", trace_id, exc)
            if response_started:
                # 响应已开始发送，无法再补救，只能向上抛
                raise
            response = JSONResponse(
                status_code=500,
                content=build_error_body(ErrorCode.SRV_001, "服务内部错误", {}, trace_id),
            )
            await response(scope, receive, send)
