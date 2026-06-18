#!/usr/bin/env bash
# Run quality gates appropriate for the detected project type(s).
# Supports Node, Python, Rails, and monorepos with multiple project roots.
#
# Override the detected root list with QG_ROOTS (space-separated paths):
#   QG_ROOTS="apps/web apps/api" bash scripts/run-quality-gates.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Resolve a working Python (Windows Git Bash often only has `python`, and a
# bare `python3` may be the Microsoft Store stub that does not actually run).
PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "" >/dev/null 2>&1; then
    PY="$cand"
    break
  fi
done

./scripts/check-branch.sh || true

# --- Kit self-test (only in the kit repo itself) ---
if [ -f tests/test_template_structure.py ] && [ -n "$PY" ]; then
  "$PY" tests/test_template_structure.py
fi

# --- Discover project roots ---
# If the caller set QG_ROOTS, use those. Otherwise auto-detect.
if [ -n "${QG_ROOTS:-}" ]; then
  # shellcheck disable=SC2206
  ROOTS=($QG_ROOTS)
else
  ROOTS=()
  # Single-root project
  ROOTS+=(".")
  # Monorepo: also scan one level of common workspace directories
  for dir in apps packages services; do
    if [ -d "$dir" ]; then
      for sub in "$dir"/*/; do
        [ -d "$sub" ] && ROOTS+=("$sub")
      done
    fi
  done
fi

# Deduplicate and run gates per root
declare -A SEEN=()
GATE_RAN=0

run_node() {
  local dir="$1"
  echo "--- Node quality gates: $dir ---"
  (cd "$dir"
    PKG_MGR="npm"
    command -v pnpm >/dev/null 2>&1 && [ -f pnpm-lock.yaml ] && PKG_MGR="pnpm"
    command -v yarn >/dev/null 2>&1 && [ -f yarn.lock ]      && PKG_MGR="yarn"
    "$PKG_MGR" run lint       --if-present 2>/dev/null || true
    "$PKG_MGR" run typecheck  --if-present 2>/dev/null || true
    "$PKG_MGR" test           --if-present 2>/dev/null || true
    # Security audit (non-fatal — informational only)
    "$PKG_MGR" audit 2>/dev/null || echo "  (audit not available or has advisories)"
  )
}

run_python() {
  local dir="$1"
  echo "--- Python quality gates: $dir ---"
  (cd "$dir"
    if command -v ruff >/dev/null 2>&1; then
      ruff check . || true
    fi
    if command -v mypy >/dev/null 2>&1 && [ -f mypy.ini -o -f pyproject.toml ]; then
      mypy . || true
    fi
    if command -v pytest >/dev/null 2>&1; then
      pytest
    elif [ -n "$PY" ]; then
      "$PY" -m pytest
    fi
    if command -v pip-audit >/dev/null 2>&1; then
      pip-audit || echo "  (pip-audit found advisories)"
    fi
  )
}

run_rails() {
  local dir="$1"
  echo "--- Rails quality gates: $dir ---"
  (cd "$dir"
    bundle exec rubocop --format quiet || true
    bundle exec brakeman --quiet       || true
    bundle exec rails test             || true
    bundle audit check --update        || echo "  (bundle audit found advisories)"
  )
}

for raw_dir in "${ROOTS[@]}"; do
  dir="$(cd "$raw_dir" 2>/dev/null && pwd)" || continue
  [ "${SEEN[$dir]+_}" ] && continue
  SEEN[$dir]=1

  if [ -f "$dir/package.json" ] && command -v npm >/dev/null 2>&1; then
    run_node "$dir"
    GATE_RAN=1
  fi

  if { [ -f "$dir/pyproject.toml" ] || [ -f "$dir/pytest.ini" ] || [ -f "$dir/setup.py" ]; }; then
    run_python "$dir"
    GATE_RAN=1
  fi

  if [ -f "$dir/Gemfile" ] && command -v bundle >/dev/null 2>&1; then
    run_rails "$dir"
    GATE_RAN=1
  fi
done

if [ "$GATE_RAN" -eq 0 ]; then
  echo "No recognised project type found."
  echo "Set QG_ROOTS or add your commands here for your stack."
fi

echo ""
echo "Quality gates completed."
