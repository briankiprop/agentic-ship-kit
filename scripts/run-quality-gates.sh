#!/usr/bin/env bash
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

if [ -f tests/test_template_structure.py ] && [ -n "$PY" ]; then
  "$PY" tests/test_template_structure.py
fi

if [ -f package.json ]; then
  if command -v npm >/dev/null 2>&1; then
    npm run lint --if-present
    npm run typecheck --if-present
    npm test --if-present
  fi
fi

if [ -f pyproject.toml ] || [ -f pytest.ini ]; then
  if command -v pytest >/dev/null 2>&1; then
    pytest
  fi
fi

echo "Quality gates completed."
