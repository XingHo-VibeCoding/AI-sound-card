"""记忆相关 Schema（TECH_DESIGN §7.2 #6-8）。"""

import uuid
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.models.memory import MemorySource, MemoryType, RecordStatus

# MemoryUpsertRequest 的规范示例（Swagger「Try it out」预填用）。
# 值都是**能直接跑通**的：tag_ids 为空（避免被自动填成假 UUID）、
# deleted_at 为 null、created_at/updated_at 为非 0 毫秒值。
MEMORY_UPSERT_EXAMPLE = {
    "type": "text",
    "title": "09-22 12:30 的记录",
    "text_content": "示例内容",
    "audio_object_key": None,
    "audio_duration_ms": None,
    "audio_format": None,
    "audio_size_bytes": None,
    "source": "quick_note",
    "record_status": "normal",
    "created_at": 1790048000000,
    "updated_at": 1790048000000,
    "deleted_at": None,
    "client_version": "1.0.0",
    "tag_ids": [],
}


class MemoryUpsertRequest(BaseModel):
    """记忆 upsert 请求体。"""

    model_config = ConfigDict(json_schema_extra={"example": MEMORY_UPSERT_EXAMPLE})

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
    # 命中 unchanged 时，请求内容是否与库中不同：True 表示客户端改了内容但
    # updated_at 未增大（本次未写入），供客户端识别「静默丢弃」并重推。
    content_differs: bool = False


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
