"""FastAPI 依赖：当前用户鉴权（TECH_DESIGN §7.1）。"""

import uuid

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.exceptions import AppError, ErrorCode
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User, UserStatus

# auto_error=False：由本模块统一抛 AUTH_003，避免漏出默认 {"detail": ...} 格式
_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """解析 Bearer access_token，返回当前用户；失败统一 AUTH_003。"""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(ErrorCode.AUTH_003, "登录已过期，请重新登录", 401)

    try:
        payload = decode_access_token(credentials.credentials)
    except jwt.PyJWTError:
        raise AppError(ErrorCode.AUTH_003, "登录已过期，请重新登录", 401)

    if payload.get("type") != "access":
        raise AppError(ErrorCode.AUTH_003, "登录已过期，请重新登录", 401)

    try:
        user_id = uuid.UUID(payload.get("sub", ""))
    except (TypeError, ValueError):
        raise AppError(ErrorCode.AUTH_003, "登录已过期，请重新登录", 401)

    user = db.get(User, user_id)
    if user is None or user.status != UserStatus.active:
        raise AppError(ErrorCode.AUTH_003, "登录已过期，请重新登录", 401)
    return user
