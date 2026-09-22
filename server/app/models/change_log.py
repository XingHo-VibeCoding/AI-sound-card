"""同步审计表 change_log（TECH_DESIGN §6.3 / §13.4）。"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, Index, Integer, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, utcnow


class ChangeEntity(str, enum.Enum):
    memory = "memory"
    tag = "tag"
    memory_tag = "memory_tag"  # 兜底审计，不作为同步拉取依据
    setting = "setting"


class ChangeAction(str, enum.Enum):
    upsert = "upsert"
    delete = "delete"


class ChangeLog(Base):
    __tablename__ = "change_log"

    seq: Mapped[int] = mapped_column(
        # SQLite 下 BIGINT 主键不是 rowid 别名、不会自增，故用 with_variant 降为 INTEGER；
        # PostgreSQL 下仍是 BigInteger（bigserial）自增。
        BigInteger().with_variant(Integer, "sqlite"),
        primary_key=True,
        autoincrement=True,
    )  # bigserial，单调递增 = 增量游标本身
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False
    )
    entity: Mapped[ChangeEntity] = mapped_column(
        Enum(ChangeEntity, native_enum=False, length=16), nullable=False
    )
    entity_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    action: Mapped[ChangeAction] = mapped_column(
        Enum(ChangeAction, native_enum=False, length=16), nullable=False
    )
    server_version: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=utcnow
    )

    __table_args__ = (
        Index("ix_change_log_user_seq", "user_id", "seq"),
    )
