"""自定义 OpenAPI 生成：补回被 FastAPI 全局 exclude_none 吞掉的示例 null 字段。

FastAPI 生成 OpenAPI 的收尾会执行 jsonable_encoder(..., exclude_none=True)，
会把请求体示例里值为 null 的字段（如 deleted_at）整条删掉。这本身无害，但会让
Swagger「Try it out」预填的请求体缺字段。这里在生成之后，把 MemoryUpsertRequest
的完整示例（含 deleted_at: null）补回 schema，保证预填的就是完整、可跑通的请求体。
"""

from fastapi import FastAPI

from app.schemas.memory import MEMORY_UPSERT_EXAMPLE


def install_custom_openapi(app: FastAPI) -> None:
    """包装 app.openapi：生成后补回示例中被 exclude_none 吞掉的 null 字段。"""
    original_openapi = app.openapi

    def custom_openapi():
        schema = original_openapi()
        try:
            schema["components"]["schemas"]["MemoryUpsertRequest"]["example"] = dict(
                MEMORY_UPSERT_EXAMPLE
            )
        except (KeyError, TypeError):
            # 结构变化时静默跳过，不影响正常 OpenAPI 输出
            pass
        return schema

    app.openapi = custom_openapi
