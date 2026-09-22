"""请求级中间件：trace_id 贯通（TECH_DESIGN §9.5）。"""

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.exceptions import new_trace_id


class TraceMiddleware(BaseHTTPMiddleware):
    """从 X-Trace-Id 透传 trace_id，否则生成；回写响应头。"""

    async def dispatch(self, request: Request, call_next):
        trace_id = request.headers.get("X-Trace-Id") or new_trace_id()
        request.state.trace_id = trace_id
        response = await call_next(request)
        response.headers["X-Trace-Id"] = trace_id
        return response
