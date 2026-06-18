#!/usr/bin/env bash
# One-line installer/updater for the Agentic Ship Kit.
#
# Install (first time):
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash
#
# Update (already installed):
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash -s -- --update
#
# Force-overwrite AGENTS.md and CLAUDE.md during update:
#   curl -fsSL ... | bash -s -- --update --force
#
# It clones the kit into a temp directory, copies the kit files into the
# current directory, and cleans up. Existing files are backed up, not deleted.
set -euo pipefail

REPO="${ASK_REPO:-https://github.com/briankiprop/agentic-ship-kit.git}"
REF="${ASK_REF:-main}"
TARGET="$PWD"
UPDATE=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --update) UPDATE=1 ;;
    --force)  FORCE=1 ;;
    *) ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH." >&2
  exit 1
fi

echo "Agentic Ship Kit — Source: $REPO@$REF"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Shallow clone for speed; only the requested ref.
git clone --depth 1 --branch "$REF" "$REPO" "$TMP/kit" >/dev/null 2>&1 || {
  echo "Failed to clone $REPO@$REF" >&2
  exit 1
}

if [ "$UPDATE" -eq 1 ]; then
  EXTRA=""
  [ "$FORCE" -eq 1 ] && EXTRA="--force"
  bash "$TMP/kit/scripts/update.sh" $EXTRA
else
  bash "$TMP/kit/scripts/install.sh" "$TARGET"
  echo ""
  echo "Done. Open this project in Claude Code and run:"
  echo "  /ship Your task here"
fi
