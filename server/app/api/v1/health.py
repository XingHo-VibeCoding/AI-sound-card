"""健康检查（无需鉴权）。对应 TECH_DESIGN §7.1 #16。"""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}
