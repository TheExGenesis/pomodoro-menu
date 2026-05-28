#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$ROOT/scripts/build.sh")"
DESTINATION="/Applications/$(basename "$APP_PATH")"
BUNDLE_ID="local.codex.pomodoro-menubar"

if [[ -e "$DESTINATION" ]]; then
  EXISTING_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$DESTINATION/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$EXISTING_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
    echo "Install target already exists and is not this app: $DESTINATION" >&2
    echo "Move it aside or choose a different install location before installing." >&2
    exit 1
  fi
  rm -rf "$DESTINATION"
fi

cp -R "$APP_PATH" "$DESTINATION"

echo "$DESTINATION"
