"""change_log.seq 在 SQLite 下改为 INTEGER（rowid 别名以自增）

Revision ID: 7d3e2f1a9b4c
Revises: 26b431c647c3
Create Date: 2026-09-21 03:10:00.000000

背景：seq 声明为 BigInteger 主键，SQLite 下 BIGINT 主键不是 rowid 别名，
插入不显式赋值时直接 NOT NULL 失败。改为 INTEGER（SQLite）后即可自增；
PostgreSQL 下 bigserial 自增正确，本迁移不动。
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7d3e2f1a9b4c'
down_revision: Union[str, Sequence[str], None] = '26b431c647c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        # SQLite 改列类型必须用 batch 模式（重建表）
        with op.batch_alter_table("change_log") as batch_op:
            batch_op.alter_column(
                "seq",
                existing_type=sa.BigInteger(),
                type_=sa.Integer(),
                existing_nullable=False,
                existing_autoincrement=True,
            )
    # PostgreSQL：BigInteger(bigserial) 自增正确，无需变更


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        with op.batch_alter_table("change_log") as batch_op:
            batch_op.alter_column(
                "seq",
                existing_type=sa.Integer(),
                type_=sa.BigInteger(),
                existing_nullable=False,
                existing_autoincrement=True,
            )
