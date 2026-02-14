from __future__ import annotations

import gc
import json
import os
import shutil
import sqlite3
import stat
import tempfile
import threading
from dataclasses import dataclass
from pathlib import Path

from .crypto import build_manifest, encrypt_package, secure_erase
from .errors import InvalidRequestError, ServiceBusyError
from .models import ConversationThread, ExportRequest


@dataclass
class ExportResult:
    output_path: Path
    message_count: int


class ExportService:
    def __init__(self) -> None:
        self._export_lock = threading.Lock()

    def export(self, conversation: ConversationThread, request: ExportRequest) -> ExportResult:
        if not self._export_lock.acquire(blocking=False):
            raise ServiceBusyError("Another export is already running")

        try:
            destination = self._resolve_destination(
                Path(request.destination_path),
                request.format,
                request.overwrite,
            )
            export_thread = self._prepare_thread_data(conversation, destination, request)

            if request.format == "text":
                self._write_text_export(destination, export_thread, request.include_attachment_paths)
            elif request.format == "json":
                self._write_json_export(destination, export_thread)
            elif request.format == "sqlite":
                self._write_sqlite_export(destination, export_thread)
            elif request.format == "encrypted_package":
                self._write_encrypted_package(destination, export_thread, request)
            else:
                raise InvalidRequestError("Unsupported export format")

            return ExportResult(output_path=destination, message_count=len(export_thread.messages))
        finally:
            self._export_lock.release()
            gc.collect()

    def _resolve_destination(self, raw_path: Path, export_format: str, overwrite: bool) -> Path:
        if "\x00" in str(raw_path):
            raise InvalidRequestError("destination_path contains an invalid byte")
        if not raw_path.is_absolute():
            raise InvalidRequestError("destination_path must be absolute")

        extension_map = {
            "text": ".txt",
            "json": ".json",
            "sqlite": ".sqlite",
            "encrypted_package": ".imexport",
        }
        expected_extension = extension_map[export_format]

        destination = raw_path.expanduser().resolve(strict=False)
        if destination.is_dir():
            destination = destination / f"conversation{expected_extension}"

        if destination.suffix.lower() != expected_extension:
            destination = destination.with_suffix(expected_extension)

        parent = destination.parent
        if not parent.exists() or not parent.is_dir():
            raise InvalidRequestError("Destination directory does not exist")
        if not os.access(parent, os.W_OK | os.X_OK):
            raise InvalidRequestError("Destination directory is not writable")
        if destination.exists() and destination.is_dir():
            raise InvalidRequestError("Destination path points to a directory")
        if destination.exists() and destination.is_symlink():
            raise InvalidRequestError("Symbolic links are not allowed for destination files")
        if self._contains_symlink(parent):
            raise InvalidRequestError("Symbolic links are not allowed in destination directory path")
        if destination.exists() and not overwrite:
            raise InvalidRequestError("Destination file already exists and overwrite is disabled")
        if not self._is_allowed_destination(destination):
            raise InvalidRequestError("Destination path is outside allowed export roots")

        return destination

    def _contains_symlink(self, path: Path) -> bool:
        current = path
        while True:
            if current.is_symlink():
                return True
            if current.parent == current:
                break
            current = current.parent
        return False

    def _is_allowed_destination(self, path: Path) -> bool:
        allowed_roots = [Path.home().resolve(), Path("/tmp").resolve(), Path(tempfile.gettempdir()).resolve()]
        return any(path.is_relative_to(root) for root in allowed_roots)

    def _prepare_thread_data(
        self,
        conversation: ConversationThread,
        destination: Path,
        request: ExportRequest,
    ) -> ConversationThread:
        export_thread = conversation.model_copy(deep=True)

        if request.copy_attachments and request.format != "encrypted_package":
            copied = self._copy_attachments(export_thread, destination)
            for message in export_thread.messages:
                for attachment in message.attachments:
                    if attachment.path and attachment.path in copied:
                        attachment.path = copied[attachment.path]

        if not request.include_attachment_paths:
            for message in export_thread.messages:
                for attachment in message.attachments:
                    attachment.path = None

        return export_thread

    def _copy_attachments(self, conversation: ConversationThread, destination: Path) -> dict[str, str]:
        attachment_dir = destination.parent / f"{destination.stem}_attachments"
        attachment_dir.mkdir(mode=0o700, exist_ok=True)

        copied_paths: dict[str, str] = {}
        for message in conversation.messages:
            for index, attachment in enumerate(message.attachments):
                if not attachment.path:
                    continue
                source = Path(attachment.path).expanduser()
                if not source.exists() or not source.is_file():
                    continue

                safe_name = Path(attachment.filename).name or f"attachment_{message.id}_{index}"
                target = attachment_dir / f"{message.id}_{index}_{safe_name}"
                shutil.copy2(source, target)
                os.chmod(target, stat.S_IRUSR | stat.S_IWUSR)
                copied_paths[attachment.path] = str(target)

        os.chmod(attachment_dir, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
        return copied_paths

    def _write_text_export(
        self,
        destination: Path,
        conversation: ConversationThread,
        include_attachment_paths: bool,
    ) -> None:
        lines: list[str] = []
        for message in conversation.messages:
            lines.append(
                f"[{message.timestamp}] {message.sender}: {(message.text or '').replace(chr(10), ' ').strip()}"
            )
            for attachment in message.attachments:
                path = attachment.path if include_attachment_paths else None
                suffix = f" {path}" if path else ""
                lines.append(
                    f"[Attachment] {attachment.filename} ({attachment.mime_type or 'unknown'}){suffix}"
                )

        content = "\n".join(lines) + "\n"
        self._secure_write_text(destination, content)

    def _write_json_export(self, destination: Path, conversation: ConversationThread) -> None:
        payload = {
            "thread": conversation.model_dump(mode="json"),
            "manifest": {
                "schema": "ConversationThread",
                "message_count": len(conversation.messages),
            },
        }
        self._secure_write_text(destination, json.dumps(payload, indent=2, ensure_ascii=False))

    def _write_sqlite_export(self, destination: Path, conversation: ConversationThread) -> None:
        if destination.exists():
            destination.unlink()

        fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.close(fd)

        connection = sqlite3.connect(destination)
        try:
            cursor = connection.cursor()
            cursor.execute(
                """
                CREATE TABLE conversations (
                  id INTEGER PRIMARY KEY,
                  title TEXT NOT NULL
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE participants (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  conversation_id INTEGER NOT NULL,
                  handle TEXT NOT NULL,
                  FOREIGN KEY(conversation_id) REFERENCES conversations(id)
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE messages (
                  id INTEGER PRIMARY KEY,
                  conversation_id INTEGER NOT NULL,
                  sender TEXT NOT NULL,
                  timestamp TEXT NOT NULL,
                  text TEXT,
                  is_from_me INTEGER NOT NULL,
                  FOREIGN KEY(conversation_id) REFERENCES conversations(id)
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE attachments (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  message_id INTEGER NOT NULL,
                  filename TEXT NOT NULL,
                  mime_type TEXT,
                  path TEXT,
                  FOREIGN KEY(message_id) REFERENCES messages(id)
                )
                """
            )

            cursor.execute(
                "INSERT INTO conversations(id, title) VALUES (?, ?)",
                (conversation.id, conversation.title),
            )
            cursor.executemany(
                "INSERT INTO participants(conversation_id, handle) VALUES (?, ?)",
                [(conversation.id, participant) for participant in conversation.participants],
            )

            message_rows = [
                (
                    message.id,
                    conversation.id,
                    message.sender,
                    message.timestamp,
                    message.text,
                    int(message.is_from_me),
                )
                for message in conversation.messages
            ]
            cursor.executemany(
                """
                INSERT INTO messages(id, conversation_id, sender, timestamp, text, is_from_me)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                message_rows,
            )

            attachment_rows = []
            for message in conversation.messages:
                for attachment in message.attachments:
                    attachment_rows.append(
                        (
                            message.id,
                            attachment.filename,
                            attachment.mime_type,
                            attachment.path,
                        )
                    )

            cursor.executemany(
                """
                INSERT INTO attachments(message_id, filename, mime_type, path)
                VALUES (?, ?, ?, ?)
                """,
                attachment_rows,
            )

            connection.commit()
        finally:
            connection.close()
            os.chmod(destination, stat.S_IRUSR | stat.S_IWUSR)

    def _write_encrypted_package(
        self,
        destination: Path,
        conversation: ConversationThread,
        request: ExportRequest,
    ) -> None:
        if not request.encrypt:
            raise InvalidRequestError("encrypt must be true for encrypted_package format")
        if not request.passphrase:
            raise InvalidRequestError("passphrase is required for encrypted exports")

        package_thread = conversation.model_copy(deep=True)
        package_files: dict[str, bytes | bytearray] = {}

        has_attachments = False
        if request.copy_attachments:
            for message in package_thread.messages:
                for index, attachment in enumerate(message.attachments):
                    if not attachment.path:
                        continue
                    source = Path(attachment.path).expanduser()
                    if not source.exists() or not source.is_file():
                        continue

                    safe_name = Path(attachment.filename).name or f"attachment_{message.id}_{index}"
                    internal_name = f"attachments/{message.id}_{index}_{safe_name}"
                    package_files[internal_name] = bytearray(source.read_bytes())
                    has_attachments = True
                    if request.include_attachment_paths:
                        attachment.path = internal_name
                    else:
                        attachment.path = None
        elif not request.include_attachment_paths:
            for message in package_thread.messages:
                for attachment in message.attachments:
                    attachment.path = None

        package_files["transcript.json"] = bytearray(
            json.dumps(
                package_thread.model_dump(mode="json"),
                ensure_ascii=False,
                indent=2,
            ).encode("utf-8")
        )
        package_files["manifest.json"] = bytearray(
            build_manifest(
                conversation_id=package_thread.id,
                message_count=len(package_thread.messages),
                transcript_name="transcript.json",
                includes_attachments=has_attachments,
            )
        )

        encrypted_payload = encrypt_package(package_files, request.passphrase)
        encrypted_buffer = bytearray(encrypted_payload)
        try:
            self._secure_write_bytes(destination, bytes(encrypted_buffer))
        finally:
            secure_erase(encrypted_buffer)
            for value in package_files.values():
                if isinstance(value, bytearray):
                    secure_erase(value)

    def _secure_write_text(self, destination: Path, content: str) -> None:
        self._secure_write_bytes(destination, content.encode("utf-8"))

    def _secure_write_bytes(self, destination: Path, content: bytes) -> None:
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
        fd = os.open(destination, flags, 0o600)
        try:
            os.write(fd, content)
            os.fchmod(fd, stat.S_IRUSR | stat.S_IWUSR)
        finally:
            os.close(fd)
