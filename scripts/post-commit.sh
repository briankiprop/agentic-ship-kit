#!/usr/bin/env bash
# ship-kit-hook: post-commit hook — rebuilds .ship-context/ when code files change.
#
# Installed by scripts/install.sh into .git/hooks/post-commit.
# Tagged "# ship-kit-hook" so it can be safely appended/removed without
# breaking other hooks in the same file.
#
# Only rebuilds if the commit touched a source code file (skips doc-only commits).
# Skips silently if .ship-context/ doesn't exist yet (no-op before first setup).
# Always exits 0 — hook failures must never block a commit.
set -uo pipefail

# Only rebuild if .ship-context/ already exists — avoids surprise first-run on
# repos where the user hasn't opted in yet.
[ -d ".ship-context" ] || exit 0

# Get files changed in this commit
CHANGED_FILES="$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || true)"

# Filter to code extensions (mirrors graphify's hooks.py pattern)
CODE_EXTENSIONS=".py .ts .js .jsx .tsx .go .rs .sh .rb .java .cpp .c .cs .kt .php"
CODE_CHANGED=0
for f in $CHANGED_FILES; do
  ext=".${f##*.}"
  for ce in $CODE_EXTENSIONS; do
    if [ "$ext" = "$ce" ]; then
      CODE_CHANGED=1
      break 2
    fi
  done
done

if [ "$CODE_CHANGED" -eq 0 ]; then
  exit 0  # doc/config-only commit — skip rebuild
fi

echo "[ship-kit] Code files changed — refreshing .ship-context/..."
bash "$(git rev-parse --show-toplevel)/scripts/build-context.sh" --force \
  "$(git rev-parse --show-toplevel)" >/dev/null 2>&1 || true

exit 0
