# AI 记忆卡

软硬一体的「AI 记忆卡」项目 —— 本项目只负责**软件层**。两条产品线：① 口语练习（M1 复读机引擎）② 日常记录 → 自动整理入库 → 辅助决策。

## 当前状态（Day 7 · MVP 第一版可运行）

- **网页版 MVP 已跑通**：根目录 `index.html` 是单文件网页（暖纸色卡片列表 + 顶栏 + 底部「速记 / 按住说话」dock），打开即用，浏览器里能读写记忆。
- **服务端闭环六接口已可用**：`server/`（FastAPI + SQLAlchemy + Alembic），auth（注册/登录/刷新/登出）+ memories CRUD + 幂等 upsert + change_log 同步游标。
- 网页通过 `fetch` 调 `http://127.0.0.1:8000/api/v1`，跨端口由服务端 CORS 放行。
- 「按住说话」录音链路是**视觉占位**，后续步骤接入。

> 怎么跑起来 → 见 [`docs/运行说明.md`](docs/运行说明.md)（两条命令：起后端 + 起网页）。

## 目录结构

```
.
├── index.html            # 网页版 MVP（单文件，零依赖）
├── app/                  # Flutter 客户端（M1 复读机引擎，真机调试）
├── server/               # FastAPI 服务端（含 .venv / dev.db / 迁移）
│   └── app/              #   core / models / api / schemas / repositories / services / db
├── docs/                 # 设计文档 + 运行说明 + 时序图/类图
├── research.md           # 竞品研究（PLAUD NOTE / 讯飞听见 / 飞书妙记）
├── PRD.md                # 产品需求文档（v0.5）
├── TECH_DESIGN.md        # 技术设计（v0.5，本地优先 + 云同步）
├── CODEBUDDY.md          # 项目规则（十章）
├── 录音卡产品-软件层SRS-需求规格说明书.md  # 口语线详规
├── .gitignore            # 忽略规则，.env 不会被上传
└── README.md             # 本文件
```

## 关于 .env

`.env` 是存数据库/密钥配置的**本地文件**，不进仓库。现在开发期不配也能跑（默认 SQLite）。`.gitignore` 已写好忽略规则，确保它以后也不会被误传。
