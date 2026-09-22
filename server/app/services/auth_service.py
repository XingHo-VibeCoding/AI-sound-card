"""鉴权业务逻辑（TECH_DESIGN §7.2 #1-4）。"""

import uuid

import jwt
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import AppError, ErrorCode
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    hash_password,
    verify_password,
)
from app.models.base import utcnow
from app.models.user import User, UserStatus
from app.schemas.auth import AuthResponse, RefreshResponse
from app.schemas.user import UserOut


def _issue_tokens(user: User) -> AuthResponse:
    access_token, exp_ts = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    return AuthResponse(
        user=UserOut.model_validate(user),
        access_token=access_token,
        refresh_token=refresh_token,
        token_expires_at=exp_ts,
    )


def register(db: Session, username: str, password: str, nickname: str | None) -> AuthResponse:
    """注册：用户名唯一，密码 Argon2id 哈希后入库。"""
    exists = db.scalar(select(User.id).where(User.username == username))
    if exists is not None:
        raise AppError(ErrorCode.AUTH_001, "用户名已存在", 409)

    user = User(username=username, password_hash=hash_password(password), nickname=nickname)
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # 并发下唯一约束兜底
        db.rollback()
        raise AppError(ErrorCode.AUTH_001, "用户名已存在", 409)
    db.refresh(user)
    return _issue_tokens(user)


def login(db: Session, username: str, password: str) -> AuthResponse:
    """登录：不区分「账号不存在 / 密码错」，统一 AUTH_002。"""
    user = db.scalar(select(User).where(User.username == username))
    if user is None or not verify_password(password, user.password_hash):
        raise AppError(ErrorCode.AUTH_002, "账号或密码不正确", 401)
    user.last_login_at = utcnow()
    db.commit()
    return _issue_tokens(user)


def refresh(db: Session, refresh_token: str) -> RefreshResponse:
    """刷新：校验 refresh_token，换发新 access_token（本期不轮换 refresh）。"""
    try:
        payload = decode_refresh_token(refresh_token)
    except jwt.PyJWTError:
        raise AppError(ErrorCode.AUTH_004, "refresh_token 已失效，请重新登录", 401)

    if payload.get("type") != "refresh":
        raise AppError(ErrorCode.AUTH_004, "refresh_token 已失效，请重新登录", 401)

    try:
        user_id = uuid.UUID(payload.get("sub", ""))
    except (TypeError, ValueError):
        raise AppError(ErrorCode.AUTH_004, "refresh_token 已失效，请重新登录", 401)

    user = db.get(User, user_id)
    if user is None or user.status != UserStatus.active:
        raise AppError(ErrorCode.AUTH_004, "refresh_token 已失效，请重新登录", 401)

    access_token, exp_ts = create_access_token(user.id)
    return RefreshResponse(access_token=access_token, token_expires_at=exp_ts)
