#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in
  run|--verify|--logs|--telemetry|--debug) ;;
  *) echo "usage: $0 [--verify|--logs|--telemetry|--debug]" >&2; exit 2 ;;
esac
pkill -x PomodoroMenuBar >/dev/null 2>&1 || true
APP_PATH="$("$ROOT/scripts/build.sh")"
if [[ "$MODE" == --debug ]]; then
  exec lldb -- "$APP_PATH/Contents/MacOS/PomodoroMenuBar"
fi
/usr/bin/open -n "$APP_PATH"
case "$MODE" in
  --verify) sleep 1; pgrep -x PomodoroMenuBar >/dev/null ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "PomodoroMenuBar"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.codex.pomodoro-menubar"' ;;
esac
