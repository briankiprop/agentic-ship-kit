#!/usr/bin/env bash
# Lightweight checkpoint for the active run. Designed to be wired as a Stop
# hook so it fires after every agent turn: it only timestamps and mirrors
# existing state (no LLM, no narrative), so it is cheap and safe to run often.
#
# It never owns phase/next_action (those belong to the agents and
# update-status.sh) -- it only stamps recency into status.md and mirrors the
# current phase/next action into handoff.md so a fresh session can resume even
# if context dies abruptly.
#
# Always exits 0: a Stop hook must never fail the user's turn.
set -uo pipefail

# No active run -> silent no-op (the common case; runs before Python so it is
# effectively instant).
LATEST=".agent-runs/latest-run.txt"
[ -f "$LATEST" ] || exit 0
RUN_DIR="$(cat "$LATEST" 2>/dev/null | tr -d '\r' | head -n1)"
[ -n "${RUN_DIR:-}" ] || exit 0
[ -d "$RUN_DIR" ] || exit 0

STATUS_FILE="$RUN_DIR/status.md"
HANDOFF_FILE="$RUN_DIR/handoff.md"
[ -f "$STATUS_FILE" ] || exit 0

# Resolve a working Python (Windows Git Bash often only has `python`, and a
# bare `python3` may be the Microsoft Store stub that does not actually run).
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
# No Python available -> nothing to stamp, but still succeed.
[ -n "$PY" ] || exit 0

LOG_FILE=".agent-runs/checkpoint.log"

"$PY" - "$STATUS_FILE" "$HANDOFF_FILE" 2>>"$LOG_FILE" <<'INNER_PY'
from __future__ import annotations
from datetime import datetime, timezone
from pathlib import Path
import re
import sys

status_path = Path(sys.argv[1])
handoff_path = Path(sys.argv[2])
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

# --- status.md: stamp last_checkpoint inside the AGENTIC_SHIP_STATUS block ---
status_text = status_path.read_text(encoding="utf-8")

if re.search(r"^last_checkpoint:.*$", status_text, flags=re.MULTILINE):
    status_text = re.sub(
        r"^last_checkpoint:.*$",
        f"last_checkpoint: {now}",
        status_text,
        count=1,
        flags=re.MULTILINE,
    )
else:
    # Insert right after updated_by: inside the metadata block, if present.
    if re.search(r"^updated_by:.*$", status_text, flags=re.MULTILINE):
        status_text = re.sub(
            r"^(updated_by:.*)$",
            rf"\1\nlast_checkpoint: {now}",
            status_text,
            count=1,
            flags=re.MULTILINE,
        )

status_path.write_text(status_text, encoding="utf-8")

# Pull current phase + next action from status to mirror into handoff.
def _grab(pattern: str, text: str) -> str:
    m = re.search(pattern, text, flags=re.MULTILINE)
    return m.group(1).strip() if m else ""

cur_phase = _grab(r"^phase:\s*(.*)$", status_text)
next_action = _grab(r"^next_action:\s*(.*)$", status_text)

# --- handoff.md: refresh last_updated + mirror phase/next_action ---
if handoff_path.is_file():
    h = handoff_path.read_text(encoding="utf-8")
    h = re.sub(r"^last_updated:.*$", f"last_updated: {now}", h, count=1, flags=re.MULTILINE)
    if cur_phase:
        h = re.sub(r"^current_phase:.*$", f"current_phase: {cur_phase}", h, count=1, flags=re.MULTILINE)
    if next_action:
        h = re.sub(r"^next_action:.*$", f"next_action: {next_action}", h, count=1, flags=re.MULTILINE)
    handoff_path.write_text(h, encoding="utf-8")

    # Warn if handoff.md is growing too large (proxy for token bloat)
    line_count = len(h.splitlines())
    if line_count > 150:
        import sys as _sys
        print(
            f"[checkpoint] WARNING: handoff.md is {line_count} lines — "
            "aim for under 150 lines (~400 words). Trim to: summary, changed files, "
            "key decisions, next action, commands run.",
            file=_sys.stderr,
        )
INNER_PY
if [ $? -ne 0 ]; then
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) checkpoint.sh: Python step failed — see $LOG_FILE" >> "$LOG_FILE"
fi

exit 0
