"""SQLAlchemy 基类与声明式映射基础。

对应 TECH_DESIGN §6.3：所有服务端表共用的元数据与命名约定。
"""

from datetime import datetime, timezone

from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase


# 统一命名约定（Alembic autogenerate 依赖它生成稳定的约束名）
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


def utcnow() -> datetime:
    """带时区的当前 UTC 时间（timestamptz 语义）。"""
    return datetime.now(timezone.utc)
