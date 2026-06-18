#!/usr/bin/env bash
# Update the Agentic Ship Kit files in the current project.
#
# Run from inside the project that has the kit installed:
#
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash --update
#
# Or directly:
#
#   bash scripts/update.sh
#
# It pulls the latest kit from GitHub, backs up existing files, and copies
# fresh versions in. Your AGENTS.md and CLAUDE.md are NOT overwritten unless
# you pass --force.
set -euo pipefail

REPO="${ASK_REPO:-https://github.com/briankiprop/agentic-ship-kit.git}"
REF="${ASK_REF:-main}"
TARGET="$PWD"
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH." >&2
  exit 1
fi

echo "Updating Agentic Ship Kit in: $TARGET"
echo "Source: $REPO@$REF"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

git clone --depth 1 --branch "$REF" "$REPO" "$TMP/kit" >/dev/null 2>&1 || {
  echo "Failed to clone $REPO@$REF" >&2
  exit 1
}

backup_and_copy() {
  local src="$1"
  local dest="$TARGET/$src"
  if [ -e "$dest" ]; then
    backup="$dest.agentic-ship-backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up $dest → $backup"
    mv "$dest" "$backup"
  fi
  cp -R "$TMP/kit/$src" "$dest"
  echo "  Updated $src"
}

# Always update tooling directories.
backup_and_copy ".claude"
backup_and_copy "templates"
backup_and_copy "scripts"

# Only update project instruction files if --force is passed.
# Users often customise AGENTS.md and CLAUDE.md, so we don't clobber them.
if [ "$FORCE" -eq 1 ]; then
  backup_and_copy "AGENTS.md"
  backup_and_copy "CLAUDE.md"
else
  echo "  Skipping AGENTS.md and CLAUDE.md (pass --force to overwrite)"
fi

chmod +x "$TARGET"/scripts/*.sh

echo ""
echo "Update complete. Backups were created for any changed files."
echo "Check the CHANGELOG for what changed: https://github.com/briankiprop/agentic-ship-kit/blob/main/CHANGELOG.md"
