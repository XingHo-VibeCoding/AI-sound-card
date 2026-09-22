"""用户相关 Schema（TECH_DESIGN §7.2）。"""

import uuid

from pydantic import BaseModel, ConfigDict


class UserOut(BaseModel):
    """对外暴露的用户信息（不含密码哈希、状态等）。"""

    id: uuid.UUID
    username: str
    nickname: str | None = None

    model_config = ConfigDict(from_attributes=True)
