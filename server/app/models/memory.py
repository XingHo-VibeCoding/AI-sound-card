"""记忆表 memories（TECH_DESIGN §6.3）。"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MemoryType(str, enum.Enum):
    audio = "audio"
    text = "text"


class MemorySource(str, enum.Enum):
    record = "record"
    quick_note = "quick_note"


class RecordStatus(str, enum.Enum):
    normal = "normal"
    incomplete = "incomplete"


class Memory(Base):
    __tablename__ = "memories"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)  # 客户端生成，服务端沿用
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False
    )
    type: Mapped[MemoryType] = mapped_column(
        Enum(MemoryType, native_enum=False, length=16), nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    text_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    audio_object_key: Mapped[str | None] = mapped_column(Text, nullable=True)  # 对象存储 key
    audio_duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    audio_format: Mapped[str | None] = mapped_column(String(16), nullable=True)
    audio_size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    source: Mapped[MemorySource] = mapped_column(
        Enum(MemorySource, native_enum=False, length=16), nullable=False
    )
    record_status: Mapped[RecordStatus] = mapped_column(
        Enum(RecordStatus, native_enum=False, length=16), nullable=False
    )
    client_version: Mapped[str] = mapped_column(String(32), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)  # 冲突判定依据
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)  # 墓碑
    server_version: Mapped[int] = mapped_column(BigInteger, nullable=False)  # 增量游标依据

    __table_args__ = (
        Index("ix_memories_user_server_version", "user_id", "server_version"),
        Index("ix_memories_user_created_at", "user_id", "created_at"),
    )
