"""记忆相关 Schema（TECH_DESIGN §7.2 #6-8）。"""

import uuid
from typing import Literal

from pydantic import BaseModel, Field

from app.models.memory import MemorySource, MemoryType, RecordStatus


class MemoryUpsertRequest(BaseModel):
    type: MemoryType
    title: str = Field(min_length=1, max_length=200)
    text_content: str | None = None
    audio_object_key: str | None = None
    audio_duration_ms: int | None = None
    audio_format: str | None = None
    audio_size_bytes: int | None = None
    source: MemorySource
    record_status: RecordStatus
    created_at: int  # epoch 毫秒
    updated_at: int  # epoch 毫秒（冲突判定依据）
    deleted_at: int | None = None  # epoch 毫秒
    client_version: str = Field(min_length=1, max_length=32)
    tag_ids: list[uuid.UUID] = Field(default_factory=list)


class MemoryUpsertResponse(BaseModel):
    id: uuid.UUID
    server_version: int
    status: Literal["upserted", "unchanged"]
    conflict: None = None


class MemoryDeleteResponse(BaseModel):
    id: uuid.UUID
    server_version: int
    status: Literal["deleted"]


class MemoryItem(BaseModel):
    """增量拉取的单条记忆（含 tag_ids，供其他设备重建关联）。"""

    id: uuid.UUID
    type: str
    title: str
    text_content: str | None = None
    audio_object_key: str | None = None
    audio_duration_ms: int | None = None
    audio_format: str | None = None
    audio_size_bytes: int | None = None
    source: str
    record_status: str
    client_version: str
    created_at: int  # epoch 毫秒
    updated_at: int  # epoch 毫秒
    deleted_at: int | None = None  # epoch 毫秒（墓碑）
    server_version: int
    tag_ids: list[uuid.UUID]


class MemoryListResponse(BaseModel):
    items: list[MemoryItem]
    next_cursor: int  # = 本批 change_log.seq 的最大值
    has_more: bool
