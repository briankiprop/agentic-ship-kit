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

TASK="${1:-new-change}"
DATE="$(date +%Y-%m-%d)"
SLUG="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)"
if [ -z "$SLUG" ]; then
  SLUG="new-change"
fi

RUN_DIR=".agent-runs/${DATE}-${SLUG}"
mkdir -p "$RUN_DIR"

copy_template() {
  local name="$1"
  if [ -f "templates/${name}" ]; then
    cp "templates/${name}" "${RUN_DIR}/${name}"
  else
    touch "${RUN_DIR}/${name}"
  fi
}

copy_template intent.md
copy_template plan.md
copy_template test-plan.md
copy_template implementation-log.md
copy_template test-report.md
copy_template review-report.md
copy_template merge-checklist.md
copy_template status.md
copy_template handoff.md

mkdir -p .agent-runs
printf '%s\n' "$RUN_DIR" > .agent-runs/latest-run.txt

"$PY" - "$RUN_DIR" "$TASK" <<'INNER_PY'
from __future__ import annotations
from datetime import datetime, timezone
from pathlib import Path
import sys

run_dir = Path(sys.argv[1])
task = sys.argv[2]
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
run_id = run_dir.name

replacements = {
    "TODO": task,
    "run_id: TODO": f"run_id: {run_id}",
    "last_updated: TODO": f"last_updated: {now}",
}

intent = run_dir / "intent.md"
text = intent.read_text(encoding="utf-8")
text = text.replace("<!-- Paste or summarize the user's request. -->", task)
intent.write_text(text, encoding="utf-8")

for name in ["status.md", "handoff.md", "plan.md"]:
    path = run_dir / name
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    text = text.replace("run_id: TODO", f"run_id: {run_id}")
    text = text.replace("last_updated: TODO", f"last_updated: {now}")
    text = text.replace("updated_by: create-run", "updated_by: create-run")
    if name == "handoff.md":
        text = text.replace("TODO: What the user asked to build, fix, or review.", task)
    path.write_text(text, encoding="utf-8")
INNER_PY

echo "$RUN_DIR"
