# AI 记忆卡 · 服务端

客户端 App + FastAPI 服务端的「服务端」部分。技术栈：Python 3.13 / FastAPI / SQLAlchemy 2.0 / Alembic / PostgreSQL（开发期可先用 SQLite 兜底）。

## 目录

- `app/` 应用代码（core / models / api，后续补 schemas / repository / service / storage）
- `alembic/` 数据库迁移
- `.env.example` 环境变量模板（复制为 `.env` 填写）
- `requirements.txt` 依赖

## 快速开始（本机，零 Docker）

```bash
cd server

# 1. 建虚拟环境并装依赖
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt

# 2. 配置环境变量（开发期可先跳过，默认用 SQLite）
copy .env.example .env   # 生产/联调时填 JWT_SECRET / DATABASE_URL 等

# 3. 建表
.venv/Scripts/python -m alembic upgrade head

# 4. 起服务
.venv/Scripts/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 5. 验证
#    浏览器打开 http://127.0.0.1:8000/docs          → OpenAPI 文档
#    浏览器打开 http://127.0.0.1:8000/api/v1/health → {"status":"ok"}
```

## 数据库

- 生产 / 联调：PostgreSQL（`DATABASE_URL=postgresql+psycopg://...`）
- 开发期兜底：SQLite（`DATABASE_URL=sqlite:///./dev.db`，默认）

> 两者由 SQLAlchemy 屏蔽差异，模型用通用类型（Uuid / Enum native_enum=False / DateTime(timezone=True)），同一套迁移可在两边跑。

## 当前进度（小步开发 · 增量 1）

- [x] 项目骨架（FastAPI + 配置 + health）
- [x] 6 张表模型（users / memories / tags / memory_tags / settings / change_log）
- [ ] auth（注册 / 登录 / 刷新 / 登出）—— 增量 2
- [ ] memories CRUD + 幂等 upsert —— 增量 3
- [ ] 同步机制（change_log 游标）—— 增量 4
