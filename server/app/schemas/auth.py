"""鉴权相关 Schema（TECH_DESIGN §7.2 #1-4）。"""

from pydantic import BaseModel, Field

from app.schemas.user import UserOut


class RegisterRequest(BaseModel):
    username: str = Field(min_length=1, max_length=20)
    password: str = Field(min_length=6, max_length=128)
    nickname: str | None = Field(default=None, max_length=32)


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=20)
    password: str = Field(min_length=1, max_length=128)


class AuthResponse(BaseModel):
    """注册 / 登录返回：用户 + 双 token。"""

    user: UserOut
    access_token: str
    refresh_token: str
    token_expires_at: int  # epoch 毫秒


class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str
    token_expires_at: int  # epoch 毫秒
