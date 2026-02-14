# MessageExporterApp

A native macOS Swift app that feels like a Messages-style client, focused on secure conversation export.

## Disclaimer
- Not affiliated with Apple.
- Messages and iMessage are trademarks of Apple Inc.

## Platform
- macOS 14.0+
- Outside Mac App Store distribution
- App Sandbox disabled for release builds intended to read `chat.db`

## Features
- Messages-like split UI with sidebar, toolbar, detail pane.
- Blocking first-run setup wizard with retry.
- Diagnostics panel with sanitized report + copy.
- Exports: text, JSON, SQLite, optional encrypted `.imexport`.
- Schema probing with query adaptation.
- Debug-only synthetic DB switch for deterministic reproduction.

## Build
```bash
cd /Users/trip/ImessageExtractor
swift build
swift test
```

## Xcode Project
```bash
cd /Users/trip/ImessageExtractor
xcodegen generate
open /Users/trip/ImessageExtractor/MessageExporterApp.xcodeproj
```
- `Release` configuration has Hardened Runtime enabled.
- App Sandbox is disabled by entitlements for outside-MAS distribution.
- Set `DEVELOPMENT_TEAM` in project signing settings before archive/export.

## Packaging
```bash
cd /Users/trip/ImessageExtractor
swift build -c release
mkdir -p .build/release/MessageExporterApp.app/Contents/MacOS
cp .build/release/MessageExporterApp .build/release/MessageExporterApp.app/Contents/MacOS/MessageExporterApp
./scripts/build-dmg.sh
```

## Troubleshooting
- Full Disk Access required:
  1. Open System Settings.
  2. Privacy & Security.
  3. Full Disk Access.
  4. Enable this app.
  5. Return and click `Retry` in setup wizard.
- Missing `chat.db`:
  - Verify path: `/Users/<you>/Library/Messages/chat.db`.
- Unsupported schema:
  - Open Diagnostics, copy report, and include it in a GitHub issue.
- Contacts denied:
  - Export still works using handles; grant Contacts access only if name resolution is needed.

## Privacy and Data Handling
- No telemetry, analytics, or network access.
- No sample data fallback on failures.
- Diagnostics include counts only, no message bodies/full handles.

## Repo Layout
```text
Sources/
  App/
  Data/
  Export/
  UI/
  Utilities/
Tests/
```
