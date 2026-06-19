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
LOCK_FILE="$HOME/.agentic-ship-running.pid"
APPROVAL_FILE="$HOME/.agentic-ship-approval"

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

# Clears the lock file — called on exit regardless of how the script ends.
# Also notifies Telegram if the script was killed externally (SIGTERM/SIGINT).
TASK_FINISHED=0
cleanup() {
  if [ "$TASK_FINISHED" -eq 0 ]; then
    send_telegram "[${PROJECT_NAME:-task}] Task was stopped or interrupted.
Task: ${TASK:-unknown}"
  fi
  rm -f "$LOCK_FILE" "$APPROVAL_FILE"
}
trap cleanup EXIT

# Background watcher: watches .agent-runs/ phase files + log heartbeat
start_progress_watcher() {
  local logfile="$1"
  local project_dir="$2"
  local project="$3"
  local task="$4"
  (
    local last_phase=""
    local last_log_line=0
    local last_update=0

    phase_label() {
      case "$1" in
        intent.md)             echo "Understanding the task..." ;;
        plan.md)               echo "Planning..." ;;
        test-plan.md)          echo "Designing tests..." ;;
        implementation-log.md) echo "Writing code..." ;;
        test-report.md)        echo "Running tests..." ;;
        review-report.md)      echo "Reviewing..." ;;
        *)                     echo "" ;;
      esac
    }

    while true; do
      sleep 8
      [ -f "$LOCK_FILE" ] || break

      # 1. Phase detection — watch .agent-runs/<run-id>/ for new files
      local run_dir=""
      local latest="$project_dir/.agent-runs/latest-run.txt"
      if [ -f "$latest" ]; then
        local rel
        rel="$(cat "$latest" 2>/dev/null)"
        [ -n "$rel" ] && run_dir="$project_dir/$rel"
      fi

      if [ -n "$run_dir" ] && [ -d "$run_dir" ]; then
        for f in intent.md plan.md test-plan.md implementation-log.md test-report.md review-report.md; do
          if [ -f "$run_dir/$f" ] && [ "$f" != "$last_phase" ]; then
            last_phase="$f"
            local label
            label="$(phase_label "$f")"
            if [ "$f" = "review-report.md" ]; then
              local verdict
              verdict="$(grep -m1 -oE 'APPROVE|REQUEST CHANGES|BLOCK' "$run_dir/$f" 2>/dev/null || true)"
              [ -n "$verdict" ] && label="Review: $verdict"
            fi
            [ -n "$label" ] && send_telegram "[$project] $label
Task: $task"
            last_update="$(date +%s)"
          fi
        done
      fi

      # 2. Heartbeat — send last meaningful log line if no phase event in 30s
      local now
      now="$(date +%s)"
      if [ $((now - last_update)) -ge 30 ]; then
        local total
        total="$(wc -l < "$logfile" 2>/dev/null || echo 0)"
        if [ "$total" -gt "$last_log_line" ]; then
          local line
          line="$(tail -n 10 "$logfile" 2>/dev/null \
            | grep -v '^\s*$' \
            | grep -v '^\[run-headless\]' \
            | grep -v '^Starting task' \
            | grep -v '^Task:' \
            | grep -v '^Log:' \
            | grep -v '^Using skill' \
            | tail -1)"
          [ -n "$line" ] && send_telegram "[$project] Still working...
$line"
          last_log_line="$total"
          last_update="$now"
        fi
      fi
    done
  ) >/dev/null 2>&1 &
  echo $!
}

PROJECT_NAME="$(basename "$PROJECT_DIR")"
echo "Starting task in: $PROJECT_DIR" | tee -a "$LOGFILE"
echo "Task: $TASK" | tee -a "$LOGFILE"
echo "Log: $LOGFILE" | tee -a "$LOGFILE"

send_telegram "Starting task on $PROJECT_NAME
Task: $TASK"

# Write lock file — use BASHPID which reflects the actual running shell's PID
echo "${BASHPID:-$$}" > "$LOCK_FILE"

cd "$PROJECT_DIR"

# Start background progress watcher
WATCHER_PID=$(start_progress_watcher "$LOGFILE" "$PROJECT_DIR" "$PROJECT_NAME" "$TASK")

# Resolve skill file: project /ship takes priority, then global /ship-skit
# 1. Project-level /ship
# 2. Project-level /ship-skit
# 3. Global ~/.claude/skills/ship-skit
# 4. Global ~/.claude/skills/ship (unlikely but handle it)
SKILL_FILE=""
SKILL="ship-skit"

if [ -f ".claude/skills/ship/SKILL.md" ]; then
  SKILL_FILE=".claude/skills/ship/SKILL.md"
  SKILL="ship"
elif [ -f ".claude/skills/ship-skit/SKILL.md" ]; then
  SKILL_FILE=".claude/skills/ship-skit/SKILL.md"
  SKILL="ship-skit"
elif [ -f "$HOME/.claude/skills/ship-skit/SKILL.md" ]; then
  SKILL_FILE="$HOME/.claude/skills/ship-skit/SKILL.md"
  SKILL="ship-skit"
elif [ -f "$HOME/.claude/skills/ship/SKILL.md" ]; then
  SKILL_FILE="$HOME/.claude/skills/ship/SKILL.md"
  SKILL="ship"
fi

echo "Using skill: $SKILL (${SKILL_FILE:-not found})" | tee -a "$LOGFILE"

if [ -n "$SKILL_FILE" ]; then
  # Write prompt to a temp file to avoid shell quoting issues with SKILL.md content
  # Use $TMPDIR with fallback — /tmp may not exist under usr\bin\bash.exe on Windows
  PROMPT_FILE="$(mktemp "${TMPDIR:-$LOG_DIR}/agentic-ship-prompt.XXXXXX")"
  # Strip YAML frontmatter (--- ... ---) so claude doesn't parse '---' as a CLI flag
  awk '/^---/{if(front==0){front=1;next}else{front=0;next}} front==0{print}' "$SKILL_FILE" > "$PROMPT_FILE"
  printf '\n\nTask: %s\n' "$TASK" >> "$PROMPT_FILE"
else
  echo "[run-headless] WARNING: No skill file found — falling back to /${SKILL}" | tee -a "$LOGFILE"
  PROMPT_FILE="$(mktemp "${TMPDIR:-$LOG_DIR}/agentic-ship-prompt.XXXXXX")"
  printf '/%s %s\n' "$SKILL" "$TASK" > "$PROMPT_FILE"
fi

# First run — read prompt from file, pass via -p to avoid flag-parsing issues with SKILL.md frontmatter
PROMPT_CONTENT="$(cat "$PROMPT_FILE")"
rm -f "$PROMPT_FILE"

# ── Phase 1: Planning only (up to --max-turns 20) ───────────────────────────
# Claude produces the plan, writes plan.md, then stops. We then gate on approval.
EXIT=0
claude -p "$PROMPT_CONTENT" --max-turns 20 --dangerously-skip-permissions --output-format text >> "$LOGFILE" 2>&1 || EXIT=$?

# ── Approval gate ─────────────────────────────────────────────────────────────
# Read the run dir from latest-run.txt if it exists
RUN_DIR=""
LATEST_RUN="$PROJECT_DIR/.agent-runs/latest-run.txt"
if [ -f "$LATEST_RUN" ]; then
  REL_RUN="$(cat "$LATEST_RUN" 2>/dev/null)"
  [ -n "$REL_RUN" ] && RUN_DIR="$PROJECT_DIR/$REL_RUN"
fi

if [ -n "$RUN_DIR" ] && [ -f "$RUN_DIR/plan.md" ]; then
  # Strip frontmatter and send up to first 3000 chars of the plan
  PLAN_CONTENT="$(awk '/^---/{if(front==0){front=1;next}else{front=0;next}} front==0{print}' "$RUN_DIR/plan.md" \
    | grep -v '^\s*$' | head -60 | head -c 3000)"

  echo "waiting" > "$APPROVAL_FILE"

  send_telegram "[${PROJECT_NAME}] Plan ready — review and approve

${PLAN_CONTENT}

---
Reply with:
/approve — proceed with coding
/reject — cancel this task
/feedback <your notes> — change the plan, then proceed"

  echo "[run-headless] Waiting for plan approval via Telegram..." | tee -a "$LOGFILE"

  WAITED=0
  APPROVAL_RESPONSE="waiting"
  while [ "$WAITED" -lt 86400 ]; do
    sleep 10
    WAITED=$((WAITED + 10))
    APPROVAL_RESPONSE="$(cat "$APPROVAL_FILE" 2>/dev/null || echo "waiting")"
    if [ "$APPROVAL_RESPONSE" != "waiting" ] && [ -n "$APPROVAL_RESPONSE" ]; then
      break
    fi
  done

  if [ "$APPROVAL_RESPONSE" = "reject" ]; then
    echo "[run-headless] Plan rejected by user." | tee -a "$LOGFILE"
    TASK_FINISHED=1
    send_telegram "[${PROJECT_NAME}] Task cancelled.
Task: $TASK"
    exit 0
  fi

  # Build continuation prompt based on approval or feedback
  if echo "$APPROVAL_RESPONSE" | grep -q '^feedback:'; then
    FEEDBACK_NOTES="${APPROVAL_RESPONSE#feedback:}"
    CONTINUE_MSG="The user has reviewed the plan and approved it with these notes: ${FEEDBACK_NOTES}

Please update the plan accordingly and then continue with implementation. Task: $TASK"
    send_telegram "[${PROJECT_NAME}] Plan approved with feedback — continuing..."
  else
    CONTINUE_MSG="The user has approved the plan. Please continue with implementation. Task: $TASK"
    send_telegram "[${PROJECT_NAME}] Plan approved — coding now..."
  fi

  # ── Phase 2+: Implementation, testing, review (up to --max-turns 80) ────────
  EXIT=0
  cd "$PROJECT_DIR"
  claude --continue -p "$CONTINUE_MSG" --max-turns 80 --dangerously-skip-permissions --output-format text >> "$LOGFILE" 2>&1 || EXIT=$?

  # Retry on non-zero exit
  COUNT=0
  while [ "$EXIT" -ne 0 ] && [ "$COUNT" -lt "$MAX_RETRIES" ]; do
    COUNT=$((COUNT + 1))
    echo "" | tee -a "$LOGFILE"
    echo "[run-headless] Exit $EXIT — retrying ($COUNT/$MAX_RETRIES) in 10s..." | tee -a "$LOGFILE"
    send_telegram "Resuming task on $PROJECT_NAME (attempt $COUNT/$MAX_RETRIES)
Task: $TASK"
    sleep 10
    EXIT=0
    cd "$PROJECT_DIR"
    claude --continue -p "Continue the task: $TASK" --max-turns 80 --dangerously-skip-permissions --output-format text >> "$LOGFILE" 2>&1 || EXIT=$?
  done

else
  # No plan.md was produced — Claude may have asked a clarifying question or handled it inline.
  # Check if the last output looks like a question and forward it to Telegram.
  LAST_OUTPUT="$(tail -n 20 "$LOGFILE" \
    | grep -v '^\s*$' \
    | grep -v '^\[run-headless\]' \
    | grep -v '^Starting task' \
    | grep -v '^Task:' \
    | grep -v '^Log:' \
    | grep -v '^Using skill' \
    | tail -5)"
  if echo "$LAST_OUTPUT" | grep -qiE '\?$|please clarify|do you mean|which (do|would)|what (do|would|should)'; then
    send_telegram "[${PROJECT_NAME}] Claude needs clarification before starting:

${LAST_OUTPUT}

Reply with /ship ${PROJECT_NAME} <clarified task> to restart."
  fi

  COUNT=0
  while [ "$EXIT" -ne 0 ] && [ "$COUNT" -lt "$MAX_RETRIES" ]; do
    COUNT=$((COUNT + 1))
    echo "" | tee -a "$LOGFILE"
    echo "[run-headless] Exit $EXIT — retrying ($COUNT/$MAX_RETRIES) in 10s..." | tee -a "$LOGFILE"
    send_telegram "Resuming task on $PROJECT_NAME (attempt $COUNT/$MAX_RETRIES)
Task: $TASK"
    sleep 10
    EXIT=0
    cd "$PROJECT_DIR"
    claude --continue -p "Continue the task: $TASK" --max-turns 80 --dangerously-skip-permissions --output-format text >> "$LOGFILE" 2>&1 || EXIT=$?
  done
fi

# Stop the progress watcher
kill "$WATCHER_PID" 2>/dev/null || true

if [ "$EXIT" -eq 0 ]; then
  echo "" | tee -a "$LOGFILE"
  echo "[run-headless] Task complete." | tee -a "$LOGFILE"
  # Send final snippet — filter out Claude's conversational lines and questions
  SUMMARY="$(tail -n 20 "$LOGFILE" \
    | grep -v '^\s*$' \
    | grep -v '^\[run-headless\]' \
    | grep -v '^Starting task' \
    | grep -v '^Task:' \
    | grep -v '^Log:' \
    | grep -v '^Using skill' \
    | grep -v -i '^\(Do you\|Would you\|Should I\|Shall I\|Please \|Let me know\|approve\|---\)' \
    | tail -3)"
  send_telegram "Task complete on $PROJECT_NAME
Task: $TASK${SUMMARY:+

$SUMMARY}"
else
  echo "" | tee -a "$LOGFILE"
  echo "[run-headless] Failed after $MAX_RETRIES retries (exit $EXIT)." | tee -a "$LOGFILE"
  LAST_ERROR="$(tail -n 5 "$LOGFILE" | grep -v '^\s*$' | tail -3)"
  send_telegram "Task failed on $PROJECT_NAME after $MAX_RETRIES retries.
Task: $TASK

$LAST_ERROR"
fi

# Mark finished so cleanup trap doesn't send a spurious "stopped" message
TASK_FINISHED=1
exit $EXIT
