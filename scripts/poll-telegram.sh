#!/usr/bin/env bash
# Poll Telegram for commands and run them headlessly.
#
# Run this once to start listening (stays in foreground):
#   bash scripts/poll-telegram.sh
#
# Or run it in the background:
#   nohup bash scripts/poll-telegram.sh >> ~/.agentic-ship-runs/poll.log 2>&1 &
#
# To start automatically when your PC boots (Linux systemd):
#   See the comment at the bottom of this file.
#
# Supported Telegram commands:
#   /ship <project-alias> <task>      — run a task on a registered project
#   /ship <task>                      — run on the only registered project (if just one)
#   /projects                         — list registered projects
#   /status                           — show current run status
#   /stop                             — stop the current running task
#
# Register projects first:
#   bash scripts/register-project.sh /path/to/myapp myapp
set -uo pipefail

CONFIG="$HOME/.agentic-ship-telegram"
PROJECTS_FILE="$HOME/.agentic-ship-projects"
OFFSET_FILE="$HOME/.agentic-ship-telegram-offset"
LOCK_FILE="$HOME/.agentic-ship-running.pid"

# Require config
if [ ! -f "$CONFIG" ]; then
  echo "Telegram not configured. Run: bash scripts/setup-telegram.sh" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || { echo "TELEGRAM_BOT_TOKEN not set in $CONFIG" >&2; exit 1; }
[ -n "${TELEGRAM_CHAT_ID:-}" ]   || { echo "TELEGRAM_CHAT_ID not set in $CONFIG" >&2; exit 1; }

# Helpers
send() {
  local msg="$1"
  curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${msg}" \
    -d "parse_mode=Markdown" \
    >/dev/null 2>&1 || true
}

lookup_project() {
  local alias="$1"
  [ -f "$PROJECTS_FILE" ] || return 1
  grep "^${alias}=" "$PROJECTS_FILE" | cut -d= -f2- | head -n1
}

default_project() {
  [ -f "$PROJECTS_FILE" ] || return 1
  local count
  count="$(wc -l < "$PROJECTS_FILE" | tr -d ' ')"
  [ "$count" -eq 1 ] || return 1
  cut -d= -f2- "$PROJECTS_FILE" | head -n1
}

# Load saved offset
OFFSET=0
[ -f "$OFFSET_FILE" ] && OFFSET="$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)"

echo "Agentic Ship Kit — Telegram poller started."
echo "Listening for commands in chat $TELEGRAM_CHAT_ID ..."
echo "Registered projects:"
[ -f "$PROJECTS_FILE" ] && cat "$PROJECTS_FILE" || echo "  (none — run register-project.sh)"
echo ""
send "🤖 Agentic Ship Kit online. Send /projects to see registered projects."

while true; do
  # Long-poll Telegram (30s timeout)
  UPDATES="$(curl -s \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates?offset=$((OFFSET+1))&timeout=30&allowed_updates=message" \
    2>/dev/null || echo '{"ok":false}')"

  # Check for parse errors
  if ! echo "$UPDATES" | grep -q '"ok":true'; then
    sleep 5
    continue
  fi

  # Process each update
  while IFS= read -r UPDATE; do
    UPDATE_ID="$(echo "$UPDATE" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*')"
    [ -z "$UPDATE_ID" ] && continue

    # Update offset
    OFFSET="$UPDATE_ID"
    echo "$OFFSET" > "$OFFSET_FILE"

    # Extract message text and chat id
    TEXT="$(echo "$UPDATE" | python3 -c "
import sys, json
try:
    u = json.loads(sys.stdin.read())
    print(u.get('message', {}).get('text', ''))
except: print('')
" 2>/dev/null || echo "")"

    SENDER_CHAT="$(echo "$UPDATE" | python3 -c "
import sys, json
try:
    u = json.loads(sys.stdin.read())
    print(u.get('message', {}).get('chat', {}).get('id', ''))
except: print('')
" 2>/dev/null || echo "")"

    [ -z "$TEXT" ] && continue

    # Security: only respond to the configured chat
    if [ "$SENDER_CHAT" != "$TELEGRAM_CHAT_ID" ]; then
      echo "Ignoring message from unknown chat: $SENDER_CHAT"
      continue
    fi

    echo "Received: $TEXT"

    case "$TEXT" in
      /projects*)
        if [ -f "$PROJECTS_FILE" ] && [ -s "$PROJECTS_FILE" ]; then
          PROJ_LIST="$(cat "$PROJECTS_FILE" | sed 's/=/ → /')"
          send "📁 Registered projects:
$PROJ_LIST

Use: /ship <alias> <task>"
        else
          send "No projects registered yet.

On your PC run:
\`bash scripts/register-project.sh /path/to/project myapp\`"
        fi
        ;;

      /status*)
        LATEST="$HOME/.agentic-ship-runs"
        if [ -f "$HOME/.agentic-ship-running.pid" ]; then
          PID="$(cat "$LOCK_FILE" 2>/dev/null)"
          if kill -0 "$PID" 2>/dev/null; then
            send "⚙️ Task is currently running (PID $PID)"
          else
            send "💤 No task is currently running."
          fi
        else
          send "💤 No task is currently running."
        fi
        ;;

      /stop*)
        if [ -f "$LOCK_FILE" ]; then
          PID="$(cat "$LOCK_FILE" 2>/dev/null)"
          if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null && send "🛑 Task stopped." || send "Could not stop task."
            rm -f "$LOCK_FILE"
          else
            send "No running task found."
            rm -f "$LOCK_FILE"
          fi
        else
          send "No running task found."
        fi
        ;;

      /ship\ *)
        # Parse: /ship [alias] task...
        ARGS="${TEXT#/ship }"
        FIRST_WORD="${ARGS%% *}"
        REST="${ARGS#* }"

        # Try to look up first word as a project alias
        PROJECT_DIR="$(lookup_project "$FIRST_WORD" 2>/dev/null || echo "")"

        if [ -n "$PROJECT_DIR" ]; then
          TASK="$REST"
        else
          # No alias found — try default (single registered project)
          PROJECT_DIR="$(default_project 2>/dev/null || echo "")"
          TASK="$ARGS"
          if [ -z "$PROJECT_DIR" ]; then
            send "❓ Project not found: \`$FIRST_WORD\`

Register it on your PC:
\`bash scripts/register-project.sh /path/to/project $FIRST_WORD\`

Or list registered projects: /projects"
            continue
          fi
        fi

        # Check if a task is already running
        if [ -f "$LOCK_FILE" ]; then
          PID="$(cat "$LOCK_FILE" 2>/dev/null)"
          if kill -0 "$PID" 2>/dev/null; then
            send "⚠️ A task is already running (PID $PID). Send /stop first."
            continue
          fi
          rm -f "$LOCK_FILE"
        fi

        # Run headlessly in background
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        send "🚀 Starting task on \`$(basename "$PROJECT_DIR")\`
Task: \`$TASK\`"

        bash "$SCRIPT_DIR/run-headless.sh" "$TASK" "$PROJECT_DIR" &
        BG_PID=$!
        echo "$BG_PID" > "$LOCK_FILE"
        echo "Started run-headless.sh PID $BG_PID"
        ;;

      /help*)
        send "🤖 *Agentic Ship Kit Commands*

/ship \`<project>\` \`<task>\` — Start a task
/projects — List registered projects
/status — Check if a task is running
/stop — Stop the current task

Examples:
/ship myapp add a login page
/ship myapp fix the checkout bug
/ship myapp refactor the user service"
        ;;

      *)
        # Ignore unknown commands silently
        ;;
    esac

  done < <(echo "$UPDATES" | python3 -c "
import sys, json
try:
    data = json.loads(sys.stdin.read())
    for u in data.get('result', []):
        print(json.dumps(u))
except: pass
" 2>/dev/null || true)

done

# ============================================================
# To run automatically on boot (Linux systemd):
#
# Create /etc/systemd/system/agentic-ship-telegram.service:
#
# [Unit]
# Description=Agentic Ship Kit Telegram Poller
# After=network.target
#
# [Service]
# Type=simple
# User=YOUR_USERNAME
# WorkingDirectory=/path/to/your/kit
# ExecStart=/bin/bash /path/to/scripts/poll-telegram.sh
# Restart=always
# RestartSec=10
#
# [Install]
# WantedBy=multi-user.target
#
# Then:
#   sudo systemctl enable agentic-ship-telegram
#   sudo systemctl start agentic-ship-telegram
# ============================================================
