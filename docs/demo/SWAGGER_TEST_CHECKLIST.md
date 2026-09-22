# Swagger 测试清单 · 闭环六接口（浏览器版，不用终端）

> 服务地址：<http://127.0.0.1:8000/docs>
> 适用：AI 记忆卡 服务端 v0.5 闭环六接口（auth 4 + me 1 + memories 3）

## 开始前

1. 浏览器打开 <http://127.0.0.1:8000/docs>
2. 按 **Ctrl + F5** 强制刷新一次（保证拿到最新接口说明和示例）
3. 已登录过的话，token 可能已过期；如果某一步返回 **401**，回到第 2 步重新登录一次即可

---

## 第 1 步 · 健康检查（不需要登录）

| 项 | 内容 |
|---|---|
| 接口 | `GET /api/v1/health` |
| 操作 | 展开 → **Try it out** → **Execute** |
| 期望 | `200`，`{"status": "ok"}` |

## 第 2 步 · 注册

| 项 | 内容 |
|---|---|
| 接口 | `POST /api/v1/auth/register` |
| 请求体 | `{"username": "mird01", "password": "123456", "nickname": "Mird"}` |
| 期望 | `201`，返回里有 `access_token`、`refresh_token`、`user` |
| 拿 token | 把 `access_token` 那一串（很长，以 `eyJ` 开头）**整条复制** |

> `username` 不能重复。若报 `409 AUTH_001 用户名已存在`，把名字改成 `mird02` 之类再试。

## 第 3 步 · 授权（右上角 Authorize）

1. 点页面右上角的 **Authorize** 按钮
2. 在 `Value` 框里粘贴刚才复制的 `access_token`（**不要**加 `Bearer ` 前缀，系统会自己加）
3. 点 **Authorize** → **Close**
4. 成功后该按钮会变成带锁状态

## 第 4 步 · 看我是谁

| 项 | 内容 |
|---|---|
| 接口 | `GET /api/v1/me` |
| 操作 | Try it out → Execute |
| 期望 | `200`，返回你注册时的 `id` / `username` / `nickname` |

## 第 5 步 · 写一条记忆（核心）

| 项 | 内容 |
|---|---|
| 接口 | `PUT /api/v1/memories/{memory_id}` |
| `memory_id` | 自己编一个 UUID：`11111111-1111-4111-8111-111111111111` |
| 请求体 | 见下方 |
| 期望 | `200`，`{"id":"11111111-...","server_version":1,"status":"upserted","conflict":null}` |

**做法（推荐）：点 `Try it out` 后直接点 `Execute`，不要手打 JSON。**
Swagger 会自动预填一份合法示例（该示例已验证是合法 JSON），直接执行就能 200。
手打 JSON 极易漏逗号，一漏就是 `422 JSON decode error`。

**如果要手改字段，用这段（已验证 200，可整段复制）：**

```json
{
  "type": "text",
  "title": "我的第一条记忆",
  "text_content": "今天学会了在 Swagger 里测接口",
  "source": "quick_note",
  "record_status": "normal",
  "created_at": 1758384000000,
  "updated_at": 1758384000000,
  "client_version": "1.0.0",
  "tag_ids": []
}
```

### 字段速查（7 个必填，少一个就 422）

| 字段 | 必填 | 取值 | 说明 |
|---|---|---|---|
| `type` | ✅ | `audio` \| `text` | 记忆类型 |
| `title` | ✅ | 字符串 | 标题 |
| `source` | ✅ | `record` \| `quick_note` | 来源：录音 / 快速记录 |
| `record_status` | ✅ | `normal` \| `incomplete` | 正常 / 不完整 |
| `created_at` | ✅ | 毫秒时间戳（数字） | **不加引号** |
| `updated_at` | ✅ | 毫秒时间戳（数字） | **不加引号** |
| `client_version` | ✅ | 如 `1.0.0` | 客户端版本 |
| `text_content` / `audio_*` / `deleted_at` / `tag_ids` | ❌ | — | 可选 |

> 想验证「引用不存在的标签也不会崩」：把 `"tag_ids": []` 改成
> `"tag_ids": ["3fa85f64-5717-4562-b3fc-2c963f66afa6"]` 再点一次 Execute，
> 期望仍然是 **200**（非法标签会被服务端过滤掉，不会报 500）。

## 第 6 步 · 原样再发一次（幂等 / 不重复创建）

- **不要改任何内容**，再点一次 **Execute**
- 期望：`200`，但 `"status"` 变成 **`unchanged`**，且 `server_version` 仍是 `1`
- 含义：同一笔数据重复上传不会产生重复记录（这是同步重试的安全前提）

## 第 7 步 · 查列表（增量拉取）

| 项 | 内容 |
|---|---|
| 接口 | `GET /api/v1/memories` |
| 参数 | `since` 留空（不填就拉全部）；`limit` 填 `20` |
| 期望 | `200`，`items` 里能看到刚才那条，且带 `tag_ids` / `server_version` / `next_cursor` |

## 第 8 步 · 删除（墓碑，不是真删）

| 项 | 内容 |
|---|---|
| 接口 | `DELETE /api/v1/memories/{memory_id}` |
| `memory_id` | 填第 5 步那个：`11111111-1111-4111-8111-111111111111` |
| 期望 | `200`，`{"status":"deleted","server_version":2}` |
| 验证 | 再执行第 7 步查列表，该条的 `deleted_at` **不为 null**（服务端只打墓碑，不物理删，多端才能同步到「删除」这个动作） |

## 第 9 步 · 刷新令牌

| 项 | 内容 |
|---|---|
| 接口 | `POST /api/v1/auth/refresh` |
| 请求体 | `{"refresh_token": "第 2 步拿到的 refresh_token"}` |
| 期望 | `200`，返回新的 `access_token` |

---

## 常见错误对照

| 返回 | 含义 | 怎么办 |
|---|---|---|
| `401 AUTH_003` | 没登录 / token 过期 | 重新登录（第 2 步）+ 重新 Authorize（第 3 步） |
| `409 AUTH_001` | 用户名已存在 | 换个 username |
| `403 AUTH_005` | 访问了别人的数据 | 检查 token 是不是当前用户的 |
| `422 VALID_001` + `JSON decode error` | **请求体 JSON 语法写错了**（漏逗号、多/少大括号、用了中文标点） | 全选清空输入框，重新粘贴上面的完整 body；或直接点 Execute 用预填内容 |
| `422 VALID_001` + `Field required` | 少了必填字段 | 对照「字段速查」补全 7 个必填项 |
| `422 VALID_001` + `Input should be ...` | 字段值类型/枚举不对 | 对照「字段速查」的取值列 |
| `500 SRV_001` | 服务端异常 | 记下页面右上角的 `trace_id`，交给开发定位 |

> 所有错误都是统一格式：`{"error": {"code": "...", "message": "...", "trace_id": "..."}}`。
> `trace_id` 是排查问题最重要的线索。
