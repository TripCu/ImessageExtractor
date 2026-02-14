from __future__ import annotations

import json
import os
import sqlite3
import stat
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.crypto import decrypt_package
from app.main import app

TEST_TOKEN = "t" * 48


@pytest.fixture()
def sample_chat_db(tmp_path: Path) -> Path:
    db_path = tmp_path / "chat.db"
    with sqlite3.connect(db_path) as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            CREATE TABLE chat (
              ROWID INTEGER PRIMARY KEY,
              guid TEXT,
              display_name TEXT,
              chat_identifier TEXT
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE message (
              ROWID INTEGER PRIMARY KEY,
              text TEXT,
              date INTEGER,
              is_from_me INTEGER,
              handle_id INTEGER
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE chat_message_join (
              chat_id INTEGER,
              message_id INTEGER
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE handle (
              ROWID INTEGER PRIMARY KEY,
              id TEXT
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE attachment (
              ROWID INTEGER PRIMARY KEY,
              filename TEXT,
              mime_type TEXT,
              transfer_name TEXT
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE message_attachment_join (
              message_id INTEGER,
              attachment_id INTEGER
            )
            """
        )

        cursor.execute(
            "INSERT INTO chat(ROWID, guid, display_name, chat_identifier) VALUES (1, ?, ?, ?)",
            ("chat-guid-1", "Alice", "alice@example.com"),
        )
        cursor.execute(
            "INSERT INTO handle(ROWID, id) VALUES (1, ?)",
            ("alice@example.com",),
        )
        cursor.execute(
            "INSERT INTO message(ROWID, text, date, is_from_me, handle_id) VALUES (1, ?, ?, 0, 1)",
            ("hello", 700000000000000000),
        )
        cursor.execute(
            "INSERT INTO chat_message_join(chat_id, message_id) VALUES (1, 1)",
        )
        connection.commit()

    return db_path


@pytest.fixture()
def client(monkeypatch: pytest.MonkeyPatch, sample_chat_db: Path) -> TestClient:
    monkeypatch.setenv("APP_API_TOKEN", TEST_TOKEN)
    monkeypatch.setenv("IMESSAGE_DB_PATH", str(sample_chat_db))

    with TestClient(app) as test_client:
        yield test_client


def auth_header() -> dict[str, str]:
    return {"Authorization": f"Bearer {TEST_TOKEN}"}


def test_health_requires_authorization(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 401


def test_list_conversations_with_authorization(client: TestClient) -> None:
    response = client.get("/conversations", headers=auth_header())

    assert response.status_code == 200
    payload = response.json()
    assert payload["conversations"][0]["title"] == "Alice"


def test_json_export_writes_secure_file(client: TestClient, tmp_path: Path) -> None:
    destination = tmp_path / "thread.json"

    response = client.post(
        "/conversations/1/export",
        headers=auth_header(),
        json={
            "format": "json",
            "destination_path": str(destination),
            "overwrite": False,
            "include_attachment_paths": True,
            "copy_attachments": False,
            "encrypt": False
        },
    )

    assert response.status_code == 200
    assert destination.exists()

    mode = stat.S_IMODE(os.stat(destination).st_mode)
    assert mode == 0o600

    payload = json.loads(destination.read_text(encoding="utf-8"))
    assert payload["thread"]["messages"][0]["text"] == "hello"


def test_encrypted_package_export_round_trip(client: TestClient, tmp_path: Path) -> None:
    destination = tmp_path / "thread.imexport"
    passphrase = "RoundTripPassphrase#123"

    response = client.post(
        "/conversations/1/export",
        headers=auth_header(),
        json={
            "format": "encrypted_package",
            "destination_path": str(destination),
            "overwrite": False,
            "include_attachment_paths": True,
            "copy_attachments": False,
            "encrypt": True,
            "passphrase": passphrase
        },
    )

    assert response.status_code == 200

    package = decrypt_package(destination.read_bytes(), passphrase)
    assert "manifest.json" in package
    assert "transcript.json" in package
