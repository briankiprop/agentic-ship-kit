#!/usr/bin/env bash
# Run a task headlessly with auto-resume on context exhaustion.
#
# Usage:
#   bash scripts/run-headless.sh "add a login page" [/path/to/project]
#
# If project path is omitted, uses the current directory.
# Output is logged to ~/.agentic-ship-runs/<date>-<slug>.log
#
# The script retries with `claude --continue` if Claude exits mid-task,
# up to MAX_RETRIES times.
set -euo pipefail

TASK="${1:-}"
PROJECT_DIR="${2:-$PWD}"
MAX_RETRIES=5
LOG_DIR="$HOME/.agentic-ship-runs"
CONFIG="$HOME/.agentic-ship-telegram"

if [ -z "$TASK" ]; then
  echo "Usage: bash scripts/run-headless.sh \"your task\" [/path/to/project]" >&2
  exit 1
fi

# Validate project directory
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
  echo "Project directory not found: $PROJECT_DIR" >&2
  exit 1
}

mkdir -p "$LOG_DIR"
SLUG="$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/-$//')"
LOGFILE="$LOG_DIR/$(date +%Y-%m-%d-%H%M%S)-${SLUG}.log"

send_telegram() {
  local msg="$1"
  [ -f "$CONFIG" ] || return 0
  # shellcheck disable=SC1090
  source "$CONFIG" 2>/dev/null || return 0
  [ -n "${TELEGRAM_BOT_TOKEN:-}" ] || return 0
  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${msg}" \
    >/dev/null 2>&1 || true
}

PROJECT_NAME="$(basename "$PROJECT_DIR")"
echo "Starting task in: $PROJECT_DIR" | tee -a "$LOGFILE"
echo "Task: $TASK" | tee -a "$LOGFILE"
echo "Log: $LOGFILE" | tee -a "$LOGFILE"

send_telegram "🚀 Starting task on $PROJECT_NAME
Task: \`$TASK\`
Log: $LOGFILE"

cd "$PROJECT_DIR"

# Detect whether to use /ship (per-project) or /ship-skit (global)
SKILL="ship-skit"
[ -f ".claude/skills/ship/SKILL.md" ] && SKILL="ship"

# First run
EXIT=0
claude -p "/$SKILL $TASK" --max-turns 80 >> "$LOGFILE" 2>&1 || EXIT=$?

COUNT=0
while [ $EXIT -ne 0 ] && [ $COUNT -lt $MAX_RETRIES ]; do
  COUNT=$((COUNT + 1))
  echo "" | tee -a "$LOGFILE"
  echo "[run-headless] Exit $EXIT — retrying ($COUNT/$MAX_RETRIES) in 10s..." | tee -a "$LOGFILE"
  send_telegram "🔄 Resuming task on $PROJECT_NAME (attempt $COUNT/$MAX_RETRIES)
Task: \`$TASK\`"
  sleep 10
  EXIT=0
  cd "$PROJECT_DIR"
  claude --continue -p "continue" --max-turns 80 >> "$LOGFILE" 2>&1 || EXIT=$?
done

if [ $EXIT -eq 0 ]; then
  echo "" | tee -a "$LOGFILE"
  echo "[run-headless] Task complete." | tee -a "$LOGFILE"
  send_telegram "✅ Task complete on $PROJECT_NAME
Task: \`$TASK\`"
else
  echo "" | tee -a "$LOGFILE"
  echo "[run-headless] Failed after $MAX_RETRIES retries (exit $EXIT)." | tee -a "$LOGFILE"
  send_telegram "❌ Task failed on $PROJECT_NAME after $MAX_RETRIES retries.
Task: \`$TASK\`
Check log: $LOGFILE"
fi

exit $EXIT
