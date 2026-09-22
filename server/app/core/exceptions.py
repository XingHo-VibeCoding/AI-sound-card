"""统一错误模型与错误码（TECH_DESIGN §7.3 / §9.2）。

所有非 2xx 响应统一为：{"error": {"code", "message", "detail", "trace_id"}}。
"""

import uuid
from typing import Any

from fastapi import Request


def new_trace_id() -> str:
    """生成 8 位十六进制 trace_id。"""
    return uuid.uuid4().hex[:8]


def get_request_trace_id(request: Request) -> str:
    """优先取请求头透传的 trace_id，否则新生成。"""
    header = getattr(request.state, "trace_id", None)
    if not header and request is not None:
        header = request.headers.get("X-Trace-Id")
    return header or new_trace_id()


class ErrorCode:
    """服务端错误码（照抄 TECH_DESIGN §9.2，不新增）。"""

    AUTH_001 = "AUTH_001"  # 409 用户名已存在
    AUTH_002 = "AUTH_002"  # 401 账号或密码不正确
    AUTH_003 = "AUTH_003"  # 401 access_token 过期/无效
    AUTH_004 = "AUTH_004"  # 401 refresh_token 失效
    AUTH_005 = "AUTH_005"  # 403 跨账号
    VALID_001 = "VALID_001"  # 422 参数校验失败
    NOTFOUND_001 = "NOTFOUND_001"  # 404 资源不存在
    SRV_001 = "SRV_001"  # 500 内部错误


class AppError(Exception):
    """业务异常：携带错误码、HTTP 状态码与可选的 detail。"""

    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        detail: Any = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.detail = detail or {}


def build_error_body(
    code: str,
    message: str,
    detail: Any = None,
    trace_id: str | None = None,
) -> dict:
    """构造统一错误体。"""
    return {
        "error": {
            "code": code,
            "message": message,
            "detail": detail or {},
            "trace_id": trace_id or new_trace_id(),
        }
    }
