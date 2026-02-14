from __future__ import annotations

import sqlite3
from datetime import UTC, datetime
from pathlib import Path

from .errors import InternalServiceError, NotFoundError
from .models import AttachmentRecord, ConversationSummary, ConversationThread, MessageRecord


def apple_timestamp_to_string(value: int | None) -> str:
    if value is None:
        return ""
    try:
        if value > 1_000_000_000_000:
            unix_seconds = (value / 1_000_000_000) + 978_307_200
        else:
            unix_seconds = value + 978_307_200
        dt = datetime.fromtimestamp(unix_seconds, tz=UTC)
        return dt.strftime("%Y-%m-%d %H:%M")
    except (OSError, OverflowError, ValueError):
        return ""


def default_chat_db_path() -> Path:
    return Path.home() / "Library" / "Messages" / "chat.db"


def open_readonly_connection(path: Path) -> sqlite3.Connection:
    # Mandatory read-only URI mode.
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


class MessagesDB:
    def __init__(self, db_path: Path | str | None = None) -> None:
        candidate = Path(db_path) if db_path is not None else default_chat_db_path()
        self.db_path = candidate.expanduser().resolve()
        if not self.db_path.is_absolute():
            raise FileNotFoundError("chat.db path must be absolute")
        if not self.db_path.exists():
            raise FileNotFoundError(f"chat.db not found at {self.db_path}")
        if self.db_path.is_symlink():
            raise FileNotFoundError("chat.db path cannot be a symlink")
        if not self.db_path.is_file():
            raise FileNotFoundError("chat.db path must point to a file")

    def _connect(self) -> sqlite3.Connection:
        connection = open_readonly_connection(self.db_path)
        connection.row_factory = sqlite3.Row
        return connection

    def list_conversations(self, search: str = "", limit: int = 200) -> list[ConversationSummary]:
        normalized_search = search.strip().lower()
        with self._connect() as connection:
            cursor = connection.execute(
                """
                WITH latest AS (
                  SELECT
                    cmj.chat_id AS chat_id,
                    m.ROWID AS message_id,
                    m.text AS text,
                    m.date AS date,
                    ROW_NUMBER() OVER (
                      PARTITION BY cmj.chat_id
                      ORDER BY m.date DESC
                    ) AS rn
                  FROM chat_message_join cmj
                  JOIN message m ON m.ROWID = cmj.message_id
                )
                SELECT
                  c.ROWID AS id,
                  COALESCE(NULLIF(c.display_name, ''), NULLIF(c.chat_identifier, ''), c.guid, 'Conversation') AS title,
                  COALESCE(latest.text, '') AS snippet,
                  COALESCE(latest.date, 0) AS raw_date
                FROM chat c
                LEFT JOIN latest ON latest.chat_id = c.ROWID AND latest.rn = 1
                WHERE (? = '' OR LOWER(COALESCE(NULLIF(c.display_name, ''), NULLIF(c.chat_identifier, ''), c.guid, '')) LIKE ?)
                ORDER BY raw_date DESC, c.ROWID DESC
                LIMIT ?
                """,
                (normalized_search, f"%{normalized_search}%", max(1, min(limit, 1000))),
            )
            rows = cursor.fetchall()

        return [
            ConversationSummary(
                id=int(row["id"]),
                title=row["title"] or f"Conversation {row['id']}",
                snippet=row["snippet"] or "",
                timestamp=apple_timestamp_to_string(int(row["raw_date"])) if row["raw_date"] else "",
            )
            for row in rows
        ]

    def get_conversation(
        self,
        conversation_id: int,
        limit: int = 200,
        before: int | None = None,
    ) -> ConversationThread:
        clamped_limit = max(1, min(limit, 10000))
        before_value = before if before is not None else 0

        with self._connect() as connection:
            chat = connection.execute(
                """
                SELECT
                  c.ROWID AS id,
                  COALESCE(NULLIF(c.display_name, ''), NULLIF(c.chat_identifier, ''), c.guid, 'Conversation') AS title
                FROM chat c
                WHERE c.ROWID = ?
                """,
                (conversation_id,),
            ).fetchone()

            if chat is None:
                raise NotFoundError("Conversation not found")

            participant_rows = connection.execute(
                """
                SELECT DISTINCT
                  CASE
                    WHEN m.is_from_me = 1 THEN 'Me'
                    ELSE COALESCE(NULLIF(h.id, ''), 'Unknown')
                  END AS participant
                FROM chat_message_join cmj
                JOIN message m ON m.ROWID = cmj.message_id
                LEFT JOIN handle h ON h.ROWID = m.handle_id
                WHERE cmj.chat_id = ?
                ORDER BY participant COLLATE NOCASE
                """,
                (conversation_id,),
            ).fetchall()

            message_rows = connection.execute(
                """
                SELECT
                  m.ROWID AS id,
                  m.text AS text,
                  m.is_from_me AS is_from_me,
                  m.date AS raw_date,
                  CASE
                    WHEN m.is_from_me = 1 THEN 'Me'
                    ELSE COALESCE(NULLIF(h.id, ''), 'Unknown')
                  END AS sender
                FROM message m
                JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
                LEFT JOIN handle h ON h.ROWID = m.handle_id
                WHERE cmj.chat_id = ?
                  AND (? = 0 OR m.ROWID < ?)
                ORDER BY m.date DESC
                LIMIT ?
                """,
                (conversation_id, before_value, before_value, clamped_limit),
            ).fetchall()

            message_ids = [int(row["id"]) for row in message_rows]
            attachment_map = self._load_attachments(connection, message_ids)

        messages = []
        for row in reversed(message_rows):
            message_id = int(row["id"])
            messages.append(
                MessageRecord(
                    id=message_id,
                    timestamp=apple_timestamp_to_string(int(row["raw_date"])) if row["raw_date"] else "",
                    sender=row["sender"],
                    text=row["text"],
                    is_from_me=bool(row["is_from_me"]),
                    attachments=attachment_map.get(message_id, []),
                )
            )

        return ConversationThread(
            id=int(chat["id"]),
            title=chat["title"] or f"Conversation {conversation_id}",
            participants=[str(row["participant"]) for row in participant_rows],
            messages=messages,
        )

    def _load_attachments(
        self,
        connection: sqlite3.Connection,
        message_ids: list[int],
    ) -> dict[int, list[AttachmentRecord]]:
        if not message_ids:
            return {}

        placeholders = ",".join("?" for _ in message_ids)
        query = f"""
            SELECT
              maj.message_id AS message_id,
              COALESCE(a.transfer_name, a.filename, 'attachment') AS filename,
              a.mime_type AS mime_type,
              a.filename AS path
            FROM message_attachment_join maj
            JOIN attachment a ON a.ROWID = maj.attachment_id
            WHERE maj.message_id IN ({placeholders})
        """

        try:
            rows = connection.execute(query, message_ids).fetchall()
        except sqlite3.DatabaseError as exc:
            raise InternalServiceError("Attachment lookup failed") from exc

        grouped: dict[int, list[AttachmentRecord]] = {}
        for row in rows:
            message_id = int(row["message_id"])
            grouped.setdefault(message_id, []).append(
                AttachmentRecord(
                    filename=str(row["filename"]),
                    mime_type=str(row["mime_type"]) if row["mime_type"] else None,
                    path=str(row["path"]) if row["path"] else None,
                )
            )

        return grouped
