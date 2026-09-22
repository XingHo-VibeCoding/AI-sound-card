"""记忆路由（TECH_DESIGN §7.2 #6-8）。"""

import uuid

from fastapi import APIRouter, Depends, Path, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.memory import (
    MemoryDeleteResponse,
    MemoryListResponse,
    MemoryUpsertRequest,
    MemoryUpsertResponse,
)
from app.services import memory_service

router = APIRouter(prefix="/memories", tags=["memories"])


@router.put("/{memory_id}", response_model=MemoryUpsertResponse)
def upsert_memory(
    payload: MemoryUpsertRequest,
    memory_id: uuid.UUID = Path(
        ...,
        description="记忆 id（客户端生成的 UUID）",
        examples=["9a7c1e00-0000-4000-8000-000000000001"],
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MemoryUpsertResponse:
    return memory_service.upsert_memory(db, current_user.id, memory_id, payload)


@router.get("", response_model=MemoryListResponse)
def list_memories(
    since: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MemoryListResponse:
    return memory_service.list_memories(db, current_user.id, since, limit)


@router.delete("/{memory_id}", response_model=MemoryDeleteResponse)
def delete_memory(
    memory_id: uuid.UUID = Path(
        ...,
        description="记忆 id（客户端生成的 UUID）",
        examples=["9a7c1e00-0000-4000-8000-000000000001"],
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MemoryDeleteResponse:
    return memory_service.delete_memory(db, current_user.id, memory_id)
