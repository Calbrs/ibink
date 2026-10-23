#!/usr/bin/env bash
#
# Development counterpart to the in-app log viewer.
#
# A build on a phone/emulator is sandboxed to the device and cannot write into
# the project folder, so the file is produced here on the host by capturing the
# app's stdout. AppLogger mirrors everything to the console in debug mode.
#
# Usage:
#   ./tool/dev_log.sh                 # run on the default device
#   ./tool/dev_log.sh -d chrome       # run in Chrome
#   ./tool/dev_log.sh --attach        # tail an already-running app
#   ./tool/dev_log.sh --truncate      # clear the log first

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/flutter.log"

ATTACH=0
TRUNCATE=0
FLUTTER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attach) ATTACH=1; shift ;;
    --truncate) TRUNCATE=1; shift ;;
    *) FLUTTER_ARGS+=("$1"); shift ;;
  esac
done

if [[ "$TRUNCATE" == "1" ]]; then
  rm -f "$LOG_FILE"
  echo "Existing log cleared."
fi

echo "Project : $PROJECT_ROOT"
echo "Log file: $LOG_FILE"

if [[ "$ATTACH" == "1" ]]; then
  echo "Attaching to running app. Press Ctrl+C to stop."
  CMD=(flutter logs)
else
  CMD=(flutter run)
  if [[ ${#FLUTTER_ARGS[@]} -gt 0 ]]; then
    CMD+=("${FLUTTER_ARGS[@]}")
  fi
fi

echo "Running: ${CMD[*]}"
echo "Tail it in a second window:  tail -f flutter.log"

printf '[%s] ===== session start =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

# Strip ANSI codes so the file stays greppable.
"${CMD[@]}" 2>&1 \
  | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' \
  | grep -v '^[[:space:]]*$' \
  | tee -a "$LOG_FILE"

printf '[%s] ===== session end =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "Done. Full log at: $LOG_FILE"