#!/usr/bin/env bash
# Remove Agentic Ship Kit files from the current project.
#
# Run from inside the project that has the kit installed:
#
#   bash scripts/uninstall.sh
#
# By default this moves kit files to a backup folder rather than deleting
# them, so you can recover if needed. Pass --delete to remove them entirely.
#
# Files NOT touched: AGENTS.md, CLAUDE.md (you may want to keep or edit these).
# Pass --all to also remove those.
set -euo pipefail

TARGET="$PWD"
DELETE=0
ALL=0

for arg in "$@"; do
  case "$arg" in
    --delete) DELETE=1 ;;
    --all)    ALL=1 ;;
    *) ;;
  esac
done

BACKUP_DIR="$TARGET/.agentic-ship-removed-$(date +%Y%m%d%H%M%S)"

remove_path() {
  local path="$TARGET/$1"
  if [ ! -e "$path" ]; then
    echo "  Not found (skipping): $1"
    return
  fi
  if [ "$DELETE" -eq 1 ]; then
    rm -rf "$path"
    echo "  Deleted $1"
  else
    mkdir -p "$BACKUP_DIR"
    mv "$path" "$BACKUP_DIR/"
    echo "  Moved $1 → $BACKUP_DIR/"
  fi
}

echo "Uninstalling Agentic Ship Kit from: $TARGET"
[ "$DELETE" -eq 1 ] && echo "Mode: permanent delete" || echo "Mode: move to backup (pass --delete to remove permanently)"

remove_path ".claude"
remove_path "templates"
remove_path "scripts"

if [ "$ALL" -eq 1 ]; then
  remove_path "AGENTS.md"
  remove_path "CLAUDE.md"
else
  echo "  Keeping AGENTS.md and CLAUDE.md (pass --all to also remove)"
fi

# Remove the gitignore block added by install.sh
GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ] && grep -qF "# agentic-ship-kit" "$GITIGNORE"; then
  # Remove from the marker line to the next blank line after the block
  python3 - "$GITIGNORE" <<'PY' 2>/dev/null || python - "$GITIGNORE" <<'PY' || true
import sys, re
path = sys.argv[1]
text = open(path).read()
# Remove the block starting with the marker
text = re.sub(r'\n# agentic-ship-kit\n.*?(?=\n\n|\Z)', '', text, flags=re.DOTALL)
open(path, 'w').write(text)
print(f"  Removed agentic-ship-kit block from .gitignore")
PY
fi

echo ""
if [ "$DELETE" -eq 0 ] && [ -d "$BACKUP_DIR" ]; then
  echo "Backup saved to: $BACKUP_DIR"
  echo "To finish cleanup: rm -rf \"$BACKUP_DIR\""
fi
echo "Uninstall complete."
