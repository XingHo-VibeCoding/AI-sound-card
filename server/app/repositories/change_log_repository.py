"""change_log 数据访问（TECH_DESIGN §6.3 / §13.4）。"""

import uuid

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.change_log import ChangeAction, ChangeEntity, ChangeLog


def next_server_version(db: Session, user_id: uuid.UUID) -> int:
    """该用户当前 max(server_version) + 1（以 change_log 为权威序列）。

    同一事务内调用一次并复用返回值，保证同一批写共用同一版本号。
    """
    result = db.scalar(
        select(func.max(ChangeLog.server_version)).where(ChangeLog.user_id == user_id)
    )
    return (result or 0) + 1


def insert_log(
    db: Session,
    user_id: uuid.UUID,
    entity: ChangeEntity,
    entity_id: uuid.UUID,
    action: ChangeAction,
    server_version: int,
) -> ChangeLog:
    """插入一行审计记录（不 commit，由调用方统一提交）。"""
    log = ChangeLog(
        user_id=user_id,
        entity=entity,
        entity_id=entity_id,
        action=action,
        server_version=server_version,
    )
    db.add(log)
    return log
