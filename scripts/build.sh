#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Pomodoro Menu"
EXECUTABLE="PomodoroMenuBar"
ARCH="$(uname -m)"
BUILD_DIR="$ROOT/.build"
DIST_DIR="$ROOT/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"

rm -rf "$BUILD_DIR" "$APP_PATH"
mkdir -p "$BUILD_DIR" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

swiftc \
  -O \
  -target "$ARCH-apple-macosx13.0" \
  -framework AppKit \
  -framework Foundation \
  -framework UserNotifications \
  "$ROOT/Sources/"*.swift \
  -o "$APP_PATH/Contents/MacOS/$EXECUTABLE"

cp "$ROOT/Info.plist" "$APP_PATH/Contents/Info.plist"
chmod +x "$APP_PATH/Contents/MacOS/$EXECUTABLE"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH" >/dev/null
fi

echo "$APP_PATH"
