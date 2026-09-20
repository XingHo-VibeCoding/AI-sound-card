"""FastAPI 入口：创建应用、挂载路由、配置生命周期。

对应 TECH_DESIGN §5.3 / §11.2。
"""

from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(
        title="AI 记忆卡 服务端",
        version="0.1.0",
        docs_url="/docs" if settings.app_env == "dev" else None,
        redoc_url="/redoc" if settings.app_env == "dev" else None,
    )

    app.include_router(api_router, prefix="/api/v1")

    return app


app = create_app()
