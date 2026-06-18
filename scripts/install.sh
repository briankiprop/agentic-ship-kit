#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: ./scripts/install.sh /path/to/your-project" >&2
  exit 2
fi

if [ ! -d "$TARGET" ]; then
  echo "Target directory does not exist: $TARGET" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

copy_path() {
  local src="$1"
  local dest="$TARGET/$src"
  if [ -e "$dest" ]; then
    backup="$dest.agentic-ship-backup.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing $dest to $backup"
    mv "$dest" "$backup"
  fi
  cp -R "$ROOT/$src" "$TARGET/$src"
}

copy_path ".claude"
copy_path "AGENTS.md"
copy_path "CLAUDE.md"
copy_path "templates"
copy_path "scripts"

chmod +x "$TARGET"/scripts/*.sh

# Append kit paths to .gitignore so they don't appear as untracked files
GITIGNORE="$TARGET/.gitignore"
MARKER="# agentic-ship-kit"

if [ ! -f "$GITIGNORE" ] || ! grep -qF "$MARKER" "$GITIGNORE"; then
  printf '\n%s\n.agent-runs/\n\n# common\n.DS_Store\nThumbs.db\n*.log\n*.tmp\n.env\n.env.*\n!.env.example\nnode_modules/\n__pycache__/\n.pytest_cache/\n.coverage\ncoverage/\ndist/\nbuild/\n' "$MARKER" >> "$GITIGNORE"
  echo "Updated .gitignore to ignore kit files."
else
  echo ".gitignore already contains kit entries — skipping."
fi

cat <<MSG
Installed Agentic Ship Kit into: $TARGET

Next steps:
  cd "$TARGET"
  claude
  /model opusplan
  /ship Your task here
MSG
