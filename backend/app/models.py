from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class HealthResponse(BaseModel):
    ok: bool
    mode: str


class ConversationSummary(BaseModel):
    id: int
    title: str
    snippet: str
    timestamp: str
    unread: bool = False


class AttachmentRecord(BaseModel):
    filename: str
    mime_type: str | None = None
    path: str | None = None


class MessageRecord(BaseModel):
    id: int
    timestamp: str
    sender: str
    text: str | None = None
    is_from_me: bool
    attachments: list[AttachmentRecord] = Field(default_factory=list)


class ConversationThread(BaseModel):
    id: int
    title: str
    participants: list[str] = Field(default_factory=list)
    messages: list[MessageRecord] = Field(default_factory=list)


class ConversationsResponse(BaseModel):
    conversations: list[ConversationSummary]


class ConversationResponse(BaseModel):
    conversation: ConversationThread


ExportFormat = Literal["text", "json", "sqlite", "encrypted_package"]


class ExportRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    format: ExportFormat
    destination_path: str
    overwrite: bool = False
    include_attachment_paths: bool = True
    copy_attachments: bool = False
    limit: int | None = Field(default=None, ge=1, le=100000)
    encrypt: bool = False
    passphrase: str | None = None

    @field_validator("destination_path")
    @classmethod
    def destination_must_be_absolute(cls, value: str) -> str:
        if "\x00" in value:
            raise ValueError("destination_path contains an invalid byte")
        path = Path(value)
        if not path.is_absolute():
            raise ValueError("destination_path must be absolute")
        return value

    @field_validator("passphrase")
    @classmethod
    def passphrase_validation(cls, value: str | None, info) -> str | None:
        encrypt = info.data.get("encrypt", False)
        if encrypt and (value is None or len(value) < 8):
            raise ValueError("passphrase is required and must be at least 8 characters")
        return value


class ExportResponse(BaseModel):
    status: str
    output_path: str
    message_count: int
