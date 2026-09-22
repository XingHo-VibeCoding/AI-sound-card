"""全局异常处理器：任何路径都输出统一错误体（TECH_DESIGN §7.3）。"""

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.exceptions import (
    AppError,
    ErrorCode,
    build_error_body,
    get_request_trace_id,
)


def register_exception_handlers(app: FastAPI) -> None:
    """注册业务/校验/HTTP 异常处理器，确保不会漏出 FastAPI 默认的 {"detail": ...} 格式。"""

    @app.exception_handler(AppError)
    async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
        trace_id = get_request_trace_id(request)
        return JSONResponse(
            status_code=exc.status_code,
            content=build_error_body(exc.code, exc.message, exc.detail, trace_id),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        trace_id = get_request_trace_id(request)
        return JSONResponse(
            status_code=422,
            content=build_error_body(
                ErrorCode.VALID_001,
                "参数校验失败",
                jsonable_encoder(exc.errors()),
                trace_id,
            ),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        trace_id = get_request_trace_id(request)
        if exc.status_code == 404:
            code, message = ErrorCode.NOTFOUND_001, "资源不存在"
        else:
            code, message = ErrorCode.SRV_001, "服务内部错误"
        return JSONResponse(
            status_code=exc.status_code,
            content=build_error_body(code, message, {}, trace_id),
        )

    # 未捕获异常由 ErrorHandlingMiddleware 兜底（返回 SRV_001 且不再向外抛），
    # 故此处不再注册 Exception 处理器，避免与中间件重复处理、重复记日志。
