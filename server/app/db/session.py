"""数据库引擎与会话（TECH_DESIGN §5.3 / §12.2）。

开发库 SQLite（dev.db），生产 PostgreSQL，同一套迁移两边都能跑。
"""

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

_connect_args: dict = {}
if settings.database_url.startswith("sqlite"):
    # FastAPI 线程池跨线程使用 SQLite 连接所需；timeout 降低跨进程写锁冲突
    _connect_args["check_same_thread"] = False
    _connect_args["timeout"] = 30

engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    connect_args=_connect_args,
)


if settings.database_url.startswith("sqlite"):

    @event.listens_for(engine, "connect")
    def _enable_sqlite_fk(dbapi_connection, connection_record) -> None:  # noqa: ANN001
        """SQLite 默认不启用外键，需显式打开以保证 tag 等外键约束生效。"""
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)


def get_db():
    """FastAPI 依赖：每个请求一个会话，请求结束关闭。"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
