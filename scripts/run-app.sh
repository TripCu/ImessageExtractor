#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Usage: $0 [debug|release]"
  exit 1
fi

./scripts/create-app-bundle.sh "$CONFIG"
open ".build/$CONFIG/MessageExporterApp.app"
