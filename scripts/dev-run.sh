#!/usr/bin/env bash
set -Eeuo pipefail

# Usage: scripts/dev-run.sh [path-to-binary]
NAME="$1"
BIN="./_build/default/bin/${NAME}.exe"
ARGS=""
if [ "$NAME" = "apiserver" ]; then
  ARGS="-port 5500"
fi
DIR="$(dirname "$BIN")"
BASE="$(basename "$BIN")"

if ! command -v inotifywait >/dev/null 2>&1; then
  echo "error: inotifywait not found. Install 'inotify-tools' (e.g. apt-get install inotify-tools)." >&2
  exit 1
fi

pid=""

start() {
  if [[ -x "$BIN" ]]; then
    echo "▶️  starting $BIN"
    "$BIN" $ARGS > "stdout.$NAME" 2> "stderr.$NAME" &
    pid=$!
  else
    echo "… waiting for $BIN to be built"
  fi
}

stop() {
  if [[ -n "${pid:-}" ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    pid=""
  fi
}

cleanup() {
  echo "⏹ stopping"
  stop
}
trap cleanup INT TERM

# Start once if present
start

# Watch the directory; restart only when the exact binary path changes
while read -r path; do
  if [[ "$path" == "$DIR/$BASE" ]]; then
    echo "🔄 change detected: $path — restarting"
    stop
    start
  fi
done < <(inotifywait -m -e close_write,move,create,delete --format '%w%f' "$DIR")
