#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MessageExporterApp"
BUILD_DIR="${BUILD_DIR:-.build/release}"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH, creating it..."
  ./scripts/create-app-bundle.sh release
fi

TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"
hdiutil create -volname "$APP_NAME" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TMP_DIR"
echo "Created $DMG_PATH"
