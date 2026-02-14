#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-Resources/synthetic-chat.db}"
TMP="${OUT}.tmp"

mkdir -p "$(dirname "$OUT")"
rm -f "$TMP"

sqlite3 "$TMP" <<'SQL'
PRAGMA journal_mode=DELETE;
PRAGMA synchronous=FULL;

CREATE TABLE chat (
  ROWID INTEGER PRIMARY KEY,
  guid TEXT,
  display_name TEXT,
  style INTEGER
);

CREATE TABLE handle (
  ROWID INTEGER PRIMARY KEY,
  id TEXT
);

CREATE TABLE message (
  ROWID INTEGER PRIMARY KEY,
  guid TEXT,
  text TEXT,
  date INTEGER,
  is_from_me INTEGER,
  handle_id INTEGER,
  attributedBody BLOB
);

CREATE TABLE chat_message_join (
  chat_id INTEGER,
  message_id INTEGER
);

CREATE TABLE chat_handle_join (
  chat_id INTEGER,
  handle_id INTEGER
);

CREATE TABLE attachment (
  ROWID INTEGER PRIMARY KEY,
  filename TEXT,
  mime_type TEXT,
  transfer_name TEXT
);

CREATE TABLE message_attachment_join (
  message_id INTEGER,
  attachment_id INTEGER
);

INSERT INTO chat VALUES (1, 'chat-guid-1', 'Synthetic Chat', 45);
INSERT INTO handle VALUES (1, '+15551230000');
INSERT INTO handle VALUES (2, '+15551239999');
INSERT INTO chat_handle_join VALUES (1, 1);
INSERT INTO chat_handle_join VALUES (1, 2);

INSERT INTO message VALUES (1, 'msg-guid-1', 'Hello fixture', 760000000, 0, 1, NULL);
INSERT INTO message VALUES (2, 'msg-guid-2', 'Reply fixture', 760000100, 1, NULL, NULL);
INSERT INTO chat_message_join VALUES (1, 1);
INSERT INTO chat_message_join VALUES (1, 2);

INSERT INTO attachment VALUES (1, 'fixture.jpg', 'image/jpeg', 'fixture.jpg');
INSERT INTO message_attachment_join VALUES (1, 1);
SQL

mv "$TMP" "$OUT"
echo "Generated synthetic DB at $OUT"
