#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Cosmogony.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/Cosmogony"
PACKAGE_SCRIPT="$ROOT_DIR/scripts/package_app.sh"

needs_rebuild() {
  if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    return 0
  fi

  if find \
    "$ROOT_DIR/Sources" \
    "$ROOT_DIR/Package.swift" \
    "$ROOT_DIR/project.yml" \
    "$ROOT_DIR/Xcode/Assets.xcassets" \
    -newer "$EXECUTABLE_PATH" \
    -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

if needs_rebuild; then
  "$PACKAGE_SCRIPT"
fi

pkill -f "$EXECUTABLE_PATH" >/dev/null 2>&1 || true
open -n "$APP_PATH"
