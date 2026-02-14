from __future__ import annotations

import os

import uvicorn
from fastapi import FastAPI, Query
from fastapi.requests import Request
from fastapi.responses import JSONResponse

from .auth import is_token_authorized, load_expected_token
from .errors import install_error_handlers
from .exporter import ExportService
from .models import ConversationResponse, ConversationsResponse, ExportRequest, ExportResponse, HealthResponse
from .messages_db import MessagesDB

app = FastAPI(
    title="iMessage Exporter Backend",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
install_error_handlers(app)


@app.on_event("startup")
def load_state() -> None:
    app.state.api_token = load_expected_token()
    db_path = os.getenv("IMESSAGE_DB_PATH")
    app.state.messages_db = MessagesDB(db_path=db_path) if db_path else MessagesDB()
    app.state.export_service = ExportService()


@app.middleware("http")
async def require_bearer_token(request: Request, call_next):
    expected_token: str = app.state.api_token
    if not is_token_authorized(request.headers.get("Authorization"), expected_token):
        return JSONResponse(
            status_code=401,
            content={"error": {"code": "unauthorized", "detail": "Unauthorized"}},
            headers={"WWW-Authenticate": "Bearer"},
        )
    return await call_next(request)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(ok=True, mode="read-only")


@app.get("/conversations", response_model=ConversationsResponse)
def list_conversations(
    search: str = Query(default="", max_length=255),
) -> ConversationsResponse:
    messages_db: MessagesDB = app.state.messages_db
    return ConversationsResponse(conversations=messages_db.list_conversations(search=search))


@app.get("/conversations/{conversation_id}", response_model=ConversationResponse)
def get_conversation(
    conversation_id: int,
    limit: int = Query(default=200, ge=1, le=10000),
    before: int | None = Query(default=None, ge=1),
) -> ConversationResponse:
    messages_db: MessagesDB = app.state.messages_db
    conversation = messages_db.get_conversation(conversation_id=conversation_id, limit=limit, before=before)
    return ConversationResponse(conversation=conversation)


@app.post("/conversations/{conversation_id}/export", response_model=ExportResponse)
def export_conversation(conversation_id: int, request: ExportRequest) -> ExportResponse:
    messages_db: MessagesDB = app.state.messages_db
    export_service: ExportService = app.state.export_service

    conversation = messages_db.get_conversation(
        conversation_id=conversation_id,
        limit=request.limit or 10000,
    )
    result = export_service.export(conversation, request)
    return ExportResponse(
        status="ok",
        output_path=str(result.output_path),
        message_count=result.message_count,
    )


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=os.getenv("APP_BIND_HOST", "127.0.0.1"),
        port=int(os.getenv("APP_BIND_PORT", "8765")),
        reload=False,
        access_log=False,
    )
