"""应用配置：集中从环境变量读取（密钥不入库、不入镜像）。

对应 TECH_DESIGN §10.1 服务端环境变量清单。
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """服务端配置。所有值来自环境变量 / .env 文件。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # 应用
    app_env: str = "dev"
    app_host: str = "0.0.0.0"
    app_port: int = 8000

    # 鉴权（本期骨架阶段占位）
    jwt_secret: str = ""
    jwt_refresh_secret: str = ""
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30

    # 数据库
    database_url: str = "sqlite:///./dev.db"
    db_pool_size: int = 5
    db_max_overflow: int = 2

    # 对象存储
    storage_backend: str = "local"  # s3 | local
    storage_local_root: str = "./data/audio"
    s3_endpoint_url: str = ""
    s3_bucket: str = ""
    s3_access_key_id: str = ""
    s3_secret_access_key: str = ""
    s3_region: str = "auto"

    # 上传限制
    max_upload_mb: int = 50

    # 其它
    # 允许跨域的来源，逗号分隔。开发期默认放行本地网页预览端口（5500）与 Swagger 宿主。
    cors_origins: str = "http://localhost:5500,http://127.0.0.1:5500,http://localhost,http://127.0.0.1"
    log_level: str = "INFO"
    argon2_time_cost: int = 3

    # AI（本期不做，占位）
    asr_provider: str = ""
    asr_api_key: str = ""
    llm_api_key: str = ""


@lru_cache
def get_settings() -> Settings:
    """返回单例配置（进程内只读一次环境变量）。"""
    return Settings()


settings = get_settings()
