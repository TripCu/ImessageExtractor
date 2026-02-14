#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="MessageExporterApp"
DISPLAY_NAME="MessageExporter"
BUNDLE_ID="${BUNDLE_ID:-org.example.MessageExporter}"
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_BUILD="${APP_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Usage: $0 [debug|release]"
  exit 1
fi

swift build -c "$CONFIG"

BUILD_DIR=".build/$CONFIG"
BIN_PATH="$BUILD_DIR/$APP_NAME"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Expected binary at $BIN_PATH"
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSContactsUsageDescription</key>
  <string>Resolve participant names from local Contacts when enabled.</string>
</dict>
</plist>
PLIST

if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

echo "Created app bundle at $APP_PATH"
