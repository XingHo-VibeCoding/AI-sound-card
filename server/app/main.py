"""FastAPI 入口：创建应用、挂载路由、配置中间件与异常处理器。

对应 TECH_DESIGN §5.3 / §11.2。
"""

from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.handlers import register_exception_handlers
from app.core.middleware import TraceMiddleware
from app.core.security import ensure_secret_keys


def create_app() -> FastAPI:
    ensure_secret_keys()

    app = FastAPI(
        title="AI 记忆卡 服务端",
        version="0.1.0",
        docs_url="/docs" if settings.app_env == "dev" else None,
        redoc_url="/redoc" if settings.app_env == "dev" else None,
    )

    app.add_middleware(TraceMiddleware)
    register_exception_handlers(app)
    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
