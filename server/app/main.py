"""FastAPI 入口：创建应用、挂载路由、配置中间件与异常处理器。

对应 TECH_DESIGN §5.3 / §11.2。
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.handlers import register_exception_handlers
from app.core.middleware import ErrorHandlingMiddleware, TraceMiddleware
from app.core.openapi import install_custom_openapi
from app.core.security import ensure_secret_keys


def create_app() -> FastAPI:
    ensure_secret_keys()

    app = FastAPI(
        title="AI 记忆卡 服务端",
        version="0.1.0",
        docs_url="/docs" if settings.app_env == "dev" else None,
        redoc_url="/redoc" if settings.app_env == "dev" else None,
    )

    # 先加内层 ErrorHandlingMiddleware，再加外层 TraceMiddleware
    # （add_middleware 后加者为最外层）：Trace 先写 trace_id，Error 再兜底异常
    app.add_middleware(ErrorHandlingMiddleware)
    app.add_middleware(TraceMiddleware)

    # CORS：放最外层，允许本地网页（localhost:5500）跨端口调用 API
    # （对应 TECH_DESIGN §env 的 CORS_ORIGINS「为 Web 预留」，Day 7 网页版落地启用）
    cors_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(api_router, prefix="/api/v1")
    install_custom_openapi(app)

    return app


app = create_app()
