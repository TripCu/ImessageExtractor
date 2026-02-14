# MessageExporter

MessageExporter is a native macOS app (SwiftUI) designed to feel like a Messages-style client where the primary action is exporting conversations.

## Disclaimer
- Not affiliated with Apple.
- Messages and iMessage are trademarks of Apple Inc.

## Platform and Distribution
- macOS 14.0+
- Distributed outside the Mac App Store
- App Sandbox disabled (required for local `chat.db` access)
- Hardened Runtime enabled for Release builds

## Core Features
- Messages-like split UI: sidebar, toolbar, conversation list, detail pane
- Blocking first-run setup wizard with retry
- Diagnostics panel with sanitized report and sanitized debug log export
- Real read-only data access from `~/Library/Messages/chat.db`
- Exports:
  - Text transcript (`.txt`)
  - JSON (`.json`)
  - SQLite (`.sqlite`)
  - Encrypted package (`.imexport`, AES-256-GCM + scrypt)
- Debug-only synthetic DB switch for deterministic reproduction

## Security Model
### Threat model
- Local message database contains sensitive personal data.
- Primary risk is accidental disclosure during logs, diagnostics, or exports.

### Controls
- Read-only open of Messages DB (`SQLITE_OPEN_READONLY`).
- No telemetry, analytics, or outbound network calls.
- Sensitive values redacted in diagnostics (`/Users/<redacted>/...`).
- Debug logging is sanitized and excludes message bodies/full handles.
- Release logging is minimal.
- Exports only through explicit user-selected `NSSavePanel` destination.
- Overwrite is disabled by default.
- Export files are written with restrictive permissions (`0600`).
- Passphrases are never persisted.

## Build
```bash
cd /Users/trip/ImessageExtractor
swift build
```

## Run (Important)
Do not use `swift run` for normal usage because it launches without a macOS app bundle identifier and breaks permissions flow.

Use:
```bash
cd /Users/trip/ImessageExtractor
./scripts/run-app.sh release
```

## Run Tests
`XCTest` is the required framework for this project.

Preferred (full Xcode):
```bash
cd /Users/trip/ImessageExtractor
xcodegen generate
xcodebuild -project MessageExporterApp.xcodeproj -scheme MessageExporterApp -destination 'platform=macOS' test
```

## Packaging DMG
```bash
cd /Users/trip/ImessageExtractor
./scripts/create-app-bundle.sh release
./scripts/build-dmg.sh
```

Run the generated app bundle directly (recommended):
```bash
open /Users/trip/ImessageExtractor/.build/release/MessageExporterApp.app
```

## Repro and Diagnostics Tools
Generate deterministic synthetic fixture DB:
```bash
cd /Users/trip/ImessageExtractor
./scripts/generate-synthetic-db.sh Resources/synthetic-chat.db
```

Collect sanitized local diagnostics from terminal (no manual SQL required):
```bash
cd /Users/trip/ImessageExtractor
./scripts/collect-diagnostics.sh
```

## Troubleshooting
### Full Disk Access required
1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Open `Full Disk Access`.
4. Enable MessageExporter.
5. Return to app and click `Retry` in setup wizard.

### Missing `chat.db`
- Expected path: `/Users/<you>/Library/Messages/chat.db`
- Verify Messages has been used on this macOS account.

### Unsupported Messages schema
- Open Diagnostics.
- Click `Copy Diagnostic Report`.
- Open a GitHub issue with the sanitized report.

### Contacts denied
- App falls back to raw handles automatically.
- Enable contact resolution only if you want display-name enrichment.

## Project Layout
```text
Sources/
  App/
  Data/
  Export/
  UI/
  Utilities/
Tests/
Config/
Resources/
scripts/
```
