#!/usr/bin/env bash
set -euo pipefail

# Resolve a working Python (Windows Git Bash often only has `python`, and a
# bare `python3` may be the Microsoft Store stub that does not actually run).
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "Python 3 not found. Install Python 3 (python3 or python on PATH)." >&2
  exit 1
fi

RUN_DIR="${1:-}"
PHASE="${2:-}"
NEXT_ACTION="${3:-}"

if [ -z "$RUN_DIR" ] || [ -z "$PHASE" ]; then
  echo "Usage: scripts/update-status.sh <run-dir> <phase> [next-action]" >&2
  exit 2
fi

if [ ! -d "$RUN_DIR" ]; then
  echo "Run folder not found: $RUN_DIR" >&2
  exit 1
fi

STATUS_FILE="$RUN_DIR/status.md"
if [ ! -f "$STATUS_FILE" ]; then
  echo "status.md not found in $RUN_DIR" >&2
  exit 1
fi

"$PY" - "$STATUS_FILE" "$PHASE" "$NEXT_ACTION" <<'INNER_PY'
from __future__ import annotations
from datetime import datetime, timezone
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
phase = sys.argv[2]
next_action = sys.argv[3] if len(sys.argv) > 3 else ""
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
text = path.read_text(encoding="utf-8")

phase_order = [
    "0-intake", "1-plan", "2-test-design", "3-approval", "4-implementation",
    "5-testing", "6-review", "7-release-check", "human-merge",
]
try:
    idx = phase_order.index(phase)
except ValueError:
    raise SystemExit(f"Unknown phase: {phase}. Expected one of: {', '.join(phase_order)}")
last_completed = phase_order[idx - 1] if idx > 0 else "none"
next_phase = phase_order[idx + 1] if idx + 1 < len(phase_order) else "done"
if not next_action:
    next_action = f"Continue to {next_phase}." if next_phase != "done" else "No next phase."

text = re.sub(r"phase: .*", f"phase: {phase}", text, count=1)
text = re.sub(r"last_completed_phase: .*", f"last_completed_phase: {last_completed}", text, count=1)
text = re.sub(r"next_phase: .*", f"next_phase: {next_phase}", text, count=1)
text = re.sub(r"next_action: .*", f"next_action: {next_action}", text, count=1)
text = re.sub(r"updated_by: .*", "updated_by: update-status", text, count=1)

text = re.sub(r"## Current phase\n\n.*?(\n\n## Phase tracker)", f"## Current phase\n\n{phase}\\1", text, flags=re.DOTALL)
text = re.sub(r"## Next action\n\n.*?(\n\n## Continue instructions)", f"## Next action\n\n{next_action}\\1", text, flags=re.DOTALL)

# Update checklist based on selected phase.
labels = {
    "0-intake": "Phase 0: Intent captured / run folder created",
    "1-plan": "Phase 1: Planner created `plan.md`",
    "2-test-design": "Phase 2: Test architect created `test-plan.md`",
    "3-approval": "Phase 3: Human approved implementation",
    "4-implementation": "Phase 4: Coder implemented approved plan",
    "5-testing": "Phase 5: Tester produced `test-report.md`",
    "6-review": "Phase 6: Reviewer produced `review-report.md`",
    "7-release-check": "Phase 7: Release checklist / PR preparation complete",
}
completed = set(phase_order[: idx + 1])
for p, label in labels.items():
    mark = "x" if p in completed else " "
    text = re.sub(rf"- \[[ x]\] {re.escape(label)}", f"- [{mark}] {label}", text)

# Add a timestamped note.
note = f"- {now}: status updated to `{phase}`. Next action: {next_action}"
if "## Notes\n" in text:
    text = text.rstrip() + "\n" + note + "\n"
else:
    text = text.rstrip() + "\n\n## Notes\n\n" + note + "\n"

path.write_text(text, encoding="utf-8")
INNER_PY

echo "Updated $STATUS_FILE to $PHASE"
