# Security Policy

## Supported Versions
- Latest `main` only.

## Threat Model
- Local sensitive data at rest in `~/Library/Messages/chat.db`.
- Risk: accidental leakage via logs, diagnostics, exports, or temp files.
- Control: read-only DB access, sanitized diagnostics, redacted logging, no telemetry/network, no message body caching.

## Security Controls
- Read-only SQLite open for Messages DB.
- No telemetry or outbound network calls.
- Logs redact sensitive values and stay minimal in release builds.
- Exports only to explicit user-selected save paths.
- File permissions set to `0600` for generated exports.
- Optional encrypted package uses AES-256-GCM + scrypt; passphrase never persisted.

## Reporting
Open a private security advisory or issue without personal data.
