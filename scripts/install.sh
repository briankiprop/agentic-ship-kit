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

cat <<MSG
Installed Agentic Ship Kit into: $TARGET

Next steps:
  cd "$TARGET"
  claude
  /model opusplan
  /ship Your task here
MSG
