"""v1 路由汇总。对应 TECH_DESIGN §7.1。

后续增量在此挂载：auth / memories / tags / settings / me。
"""

from fastapi import APIRouter

from app.api.v1 import health

api_router = APIRouter()
api_router.include_router(health.router)
