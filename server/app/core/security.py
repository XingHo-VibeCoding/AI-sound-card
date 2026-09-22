"""密码哈希（Argon2id）与 JWT 签发/校验（TECH_DESIGN §10.1）。

access_token 与 refresh_token 使用不同密钥、不同有效期、不同 type 声明。
"""

import time
import warnings

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import settings

# Argon2id：time_cost 取 settings.argon2_time_cost，memory_cost / parallelism 用库默认
_password_hasher = PasswordHasher(time_cost=settings.argon2_time_cost)

# 开发占位密钥（确定性，仅 app_env == "dev" 且密钥为空时启用）
_DEV_ACCESS_SECRET = "dev-only-access-secret-6f0e7a9b2c1d"
_DEV_REFRESH_SECRET = "dev-only-refresh-secret-9c8b7a6f5e4d"


def ensure_secret_keys() -> None:
    """校验 JWT 密钥：生产缺失或两密钥相同即报错，开发用确定性占位密钥。"""
    if not settings.jwt_secret or not settings.jwt_refresh_secret:
        if settings.app_env != "dev":
            raise RuntimeError("生产环境必须显式配置 jwt_secret 与 jwt_refresh_secret")
        if not settings.jwt_secret:
            settings.jwt_secret = _DEV_ACCESS_SECRET
            warnings.warn("jwt_secret 为空，使用开发占位密钥（勿用于生产）")
        if not settings.jwt_refresh_secret:
            settings.jwt_refresh_secret = _DEV_REFRESH_SECRET
            warnings.warn("jwt_refresh_secret 为空，使用开发占位密钥（勿用于生产）")
    if settings.jwt_secret == settings.jwt_refresh_secret:
        raise RuntimeError("jwt_secret 与 jwt_refresh_secret 不能相同")


def hash_password(password: str) -> str:
    """Argon2id 哈希（数据库只存哈希）。"""
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """校验密码；任何校验失败都返回 False（不泄露具体原因）。"""
    try:
        return _password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def _encode_token(sub: str, token_type: str, secret: str, expires_seconds: int) -> str:
    now = int(time.time())
    payload = {
        "sub": sub,
        "type": token_type,
        "iat": now,
        "exp": now + expires_seconds,
    }
    return jwt.encode(payload, secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id) -> tuple[str, int]:
    """签发 access_token，返回 (token, 过期时间戳 epoch 毫秒)。"""
    expires_seconds = settings.access_token_expire_minutes * 60
    token = _encode_token(str(user_id), "access", settings.jwt_secret, expires_seconds)
    exp_ts = int(time.time() * 1000) + expires_seconds * 1000
    return token, exp_ts


def create_refresh_token(user_id) -> str:
    """签发 refresh_token。"""
    expires_seconds = settings.refresh_token_expire_days * 24 * 3600
    return _encode_token(str(user_id), "refresh", settings.jwt_refresh_secret, expires_seconds)


def decode_access_token(token: str) -> dict:
    """校验 access_token；无效/过期抛 jwt.PyJWTError。"""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


def decode_refresh_token(token: str) -> dict:
    """校验 refresh_token；无效/过期抛 jwt.PyJWTError。"""
    return jwt.decode(token, settings.jwt_refresh_secret, algorithms=[settings.jwt_algorithm])
