#!/usr/bin/env bash
# Poll Telegram for commands and run them headlessly.
# Delegates all logic to poll-telegram.py for Windows compatibility.
#
# Run in background:
#   nohup bash scripts/poll-telegram.sh >> ~/.agentic-ship-runs/poll.log 2>&1 &
set -euo pipefail

# Resolve Python
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "Python is required but was not found." >&2
  exit 1
fi

CONFIG="$HOME/.agentic-ship-telegram"
if [ ! -f "$CONFIG" ]; then
  echo "Telegram not configured. Run: bash scripts/setup-telegram.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$PY" "$SCRIPT_DIR/poll-telegram.py"
