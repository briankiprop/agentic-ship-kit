#!/usr/bin/env bash
# Send a Telegram notification for the current run phase.
# Called by the Stop hook in .claude/settings.json after every Claude turn.
#
# Only sends a message when the phase changes — not on every turn — to avoid spam.
# Phase change is tracked in ~/.agentic-ship-last-phase.
#
# Always exits 0 (Stop hooks must never fail the user's turn).
set -uo pipefail

CONFIG="$HOME/.agentic-ship-telegram"
LAST_PHASE_FILE="$HOME/.agentic-ship-last-phase"

# If Telegram is not configured, silent no-op.
[ -f "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
source "$CONFIG" 2>/dev/null || exit 0
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || exit 0
[ -n "${TELEGRAM_CHAT_ID:-}" ] || exit 0

# Find the active run.
LATEST=".agent-runs/latest-run.txt"
[ -f "$LATEST" ] || exit 0
RUN_DIR="$(cat "$LATEST" 2>/dev/null | tr -d '\r' | head -n1)"
[ -n "${RUN_DIR:-}" ] || exit 0
[ -d "$RUN_DIR" ] || exit 0

STATUS_FILE="$RUN_DIR/status.md"
[ -f "$STATUS_FILE" ] || exit 0

# Read current phase and next_action from status.md
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
[ -n "$PY" ] || exit 0

read -r PHASE NEXT_ACTION REVIEW_DECISION RUN_ID <<< "$("$PY" - "$STATUS_FILE" <<'PY'
import sys, re
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

def grab(pattern, text, default=''):
    m = re.search(pattern, text, re.MULTILINE)
    return m.group(1).strip() if m else default

phase        = grab(r'^phase:\s*(.+)$', text)
next_action  = grab(r'^next_action:\s*(.+)$', text)
run_id       = grab(r'^run_id:\s*(.+)$', text)

# Check review-report.md for decision
import os
run_dir = os.path.dirname(path)
review_path = os.path.join(run_dir, 'review-report.md')
decision = ''
if os.path.isfile(review_path):
    rtext = open(review_path, encoding='utf-8').read()
    dm = re.search(r'##\s*Decision\s*\n+(\w[\w\s]*)', rtext)
    if dm:
        decision = dm.group(1).strip().split('\n')[0]

# Check test-report.md for pass/fail
test_result = ''
test_path = os.path.join(run_dir, 'test-report.md')
if os.path.isfile(test_path):
    ttext = open(test_path, encoding='utf-8').read()
    if re.search(r'PASS', ttext, re.IGNORECASE):
        test_result = 'PASS'
    elif re.search(r'FAIL', ttext, re.IGNORECASE):
        test_result = 'FAIL'

print(phase, '|||', next_action, '|||', decision, '|||', run_id, '|||', test_result)
PY
)" 2>/dev/null || exit 0

# Parse output
PHASE="$(echo "$PHASE" | awk -F'|||' '{print $1}' | xargs)"
NEXT_ACTION="$(echo "$PHASE $NEXT_ACTION $REVIEW_DECISION $RUN_ID" | python3 -c "
import sys
parts = sys.stdin.read().split('|||')
print(parts[1].strip() if len(parts) > 1 else '')
" 2>/dev/null || echo "")"
REVIEW_DECISION="$(echo "$PHASE $NEXT_ACTION $REVIEW_DECISION $RUN_ID" | python3 -c "
import sys
parts = sys.stdin.read().split('|||')
print(parts[2].strip() if len(parts) > 2 else '')
" 2>/dev/null || echo "")"
RUN_ID_VAL="$(echo "$PHASE $NEXT_ACTION $REVIEW_DECISION $RUN_ID" | python3 -c "
import sys
parts = sys.stdin.read().split('|||')
print(parts[3].strip() if len(parts) > 3 else '')
" 2>/dev/null || echo "")"
TEST_RESULT="$(echo "$PHASE $NEXT_ACTION $REVIEW_DECISION $RUN_ID" | python3 -c "
import sys
parts = sys.stdin.read().split('|||')
print(parts[4].strip() if len(parts) > 4 else '')
" 2>/dev/null || echo "")"

# Re-read phase cleanly from status file
PHASE="$("$PY" -c "
import sys, re
text = open('$STATUS_FILE', encoding='utf-8').read()
m = re.search(r'^phase:\s*(.+)$', text, re.MULTILINE)
print(m.group(1).strip() if m else '')
" 2>/dev/null || echo "")"

[ -n "$PHASE" ] || exit 0

# Only notify on phase change
LAST_PHASE=""
[ -f "$LAST_PHASE_FILE" ] && LAST_PHASE="$(cat "$LAST_PHASE_FILE" 2>/dev/null | tr -d '\r')"
[ "$PHASE" = "$LAST_PHASE" ] && exit 0
echo "$PHASE" > "$LAST_PHASE_FILE"

# Build message based on phase
PROJECT="$(basename "$PWD")"
TASK="$(basename "$RUN_DIR" | sed 's/^[0-9-]*-//')"

case "$PHASE" in
  1-plan)
    MSG="📋 *Plan ready* — $PROJECT
Task: \`$TASK\`
Open Claude Code and say \`yes\` to approve and start building."
    ;;
  3-approval)
    MSG="⏳ *Waiting for your approval* — $PROJECT
Task: \`$TASK\`
Open Claude Code or reply with \`approve\` to continue."
    ;;
  5-testing)
    if [ "$TEST_RESULT" = "PASS" ]; then
      MSG="✅ *Tests passed* — $PROJECT
Task: \`$TASK\`
Moving to review..."
    elif [ "$TEST_RESULT" = "FAIL" ]; then
      MSG="❌ *Tests failed* — $PROJECT
Task: \`$TASK\`
Check the test-report.md in .agent-runs/$TASK/"
    else
      MSG="🧪 *Running tests* — $PROJECT
Task: \`$TASK\`"
    fi
    ;;
  6-review)
    case "$REVIEW_DECISION" in
      *APPROVE*)  ICON="✅" ;;
      *BLOCK*)    ICON="🚨" ;;
      *)          ICON="⚠️" ;;
    esac
    DECISION_TEXT="${REVIEW_DECISION:-in progress}"
    MSG="$ICON *Review: $DECISION_TEXT* — $PROJECT
Task: \`$TASK\`"
    ;;
  7-release-check)
    MSG="🚀 *Ready to PR* — $PROJECT
Task: \`$TASK\`
Run \`/release-check\` or open a PR when ready."
    ;;
  *)
    # Silent for intake and implementation phases (too noisy)
    exit 0
    ;;
esac

# Send the message (non-fatal on failure)
curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=Markdown" \
  >/dev/null 2>&1 || true

exit 0
