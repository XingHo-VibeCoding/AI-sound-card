"""记忆↔标签关联表 memory_tags（TECH_DESIGN §6.3）。"""

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class MemoryTag(Base):
    __tablename__ = "memory_tags"

    memory_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("memories.id"), primary_key=True
    )
    tag_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("tags.id"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    server_version: Mapped[int] = mapped_column(BigInteger, nullable=False)
