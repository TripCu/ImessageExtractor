#!/usr/bin/env bash
set -euo pipefail

DB_PATH="${1:-$HOME/Library/Messages/chat.db}"
REDACTED_PATH="$(printf '%s' "$DB_PATH" | sed "s#^$HOME#/Users/<redacted>#")"

exists=false
readable=false
sqlite_open=false

[[ -f "$DB_PATH" ]] && exists=true
[[ -r "$DB_PATH" ]] && readable=true

if [[ "$exists" == true && "$readable" == true ]]; then
  if sqlite3 "$DB_PATH" 'select 1;' >/dev/null 2>&1; then
    sqlite_open=true
  fi
fi

last_error="none"
if [[ "$exists" == false ]]; then
  last_error="missing_file"
elif [[ "$sqlite_open" == false ]]; then
  last_error="permission"
fi

tables=""
chat_columns=""
message_columns=""
handle_columns=""
chat_count="0"
message_count="0"

if [[ "$sqlite_open" == true ]]; then
  tables=$(sqlite3 "$DB_PATH" "SELECT group_concat(name, ', ') FROM sqlite_master WHERE type='table' ORDER BY name;")
  chat_columns=$(sqlite3 "$DB_PATH" "PRAGMA table_info(chat);" | awk -F'|' '{print $2}' | paste -sd', ' -)
  message_columns=$(sqlite3 "$DB_PATH" "PRAGMA table_info(message);" | awk -F'|' '{print $2}' | paste -sd', ' -)
  handle_columns=$(sqlite3 "$DB_PATH" "PRAGMA table_info(handle);" | awk -F'|' '{print $2}' | paste -sd', ' -)
  chat_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM chat;" 2>/dev/null || echo "0")
  message_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM message;" 2>/dev/null || echo "0")
fi

missing=()
[[ "$tables" != *"chat"* ]] && missing+=("table.chat")
[[ "$tables" != *"message"* ]] && missing+=("table.message")
[[ "$chat_columns" != *"ROWID"* && "$chat_columns" != *"guid"* ]] && missing+=("chat.guid")
[[ "$message_columns" != *"date"* ]] && missing+=("message.date")
[[ "$message_columns" != *"is_from_me"* ]] && missing+=("message.is_from_me")

printf 'DB Path: %s\n' "$REDACTED_PATH"
printf 'File Exists: %s\n' "$exists"
printf 'File Readable: %s\n' "$readable"
printf 'SQLite Open: %s\n' "$sqlite_open"
printf 'Last Error: %s\n' "$last_error"
printf 'Chats Count: %s\n' "$chat_count"
printf 'Messages Count: %s\n' "$message_count"
printf 'Schema Tables: %s\n' "${tables:-n/a}"
printf 'Schema chat columns: %s\n' "${chat_columns:-n/a}"
printf 'Schema message columns: %s\n' "${message_columns:-n/a}"
printf 'Schema handle columns: %s\n' "${handle_columns:-n/a}"
if [[ ${#missing[@]} -eq 0 ]]; then
  printf 'Schema Missing: none\n'
else
  printf 'Schema Missing: %s\n' "$(IFS=', '; echo "${missing[*]}")"
fi
