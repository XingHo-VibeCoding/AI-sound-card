"""v1 路由汇总。对应 TECH_DESIGN §7.1。"""

from fastapi import APIRouter

from app.api.v1 import auth, health, me, memories

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(me.router)
api_router.include_router(memories.router)
