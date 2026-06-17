#!/usr/bin/env bash
# One-line installer for the Agentic Ship Kit.
#
# Run this from inside the project you want to add the kit to:
#
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash
#
# It clones the kit into a temp directory, copies the kit files into the
# current directory via install.sh, and cleans up. Existing files are backed
# up by install.sh, not overwritten.
set -euo pipefail

REPO="${ASK_REPO:-https://github.com/briankiprop/agentic-ship-kit.git}"
REF="${ASK_REF:-main}"
TARGET="$PWD"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH." >&2
  exit 1
fi

echo "Installing Agentic Ship Kit into: $TARGET"
echo "Source: $REPO@$REF"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# Shallow clone for speed; only the requested ref.
git clone --depth 1 --branch "$REF" "$REPO" "$TMP/kit" >/dev/null 2>&1 || {
  echo "Failed to clone $REPO@$REF" >&2
  exit 1
}

bash "$TMP/kit/scripts/install.sh" "$TARGET"

echo ""
echo "Done. Open this project in Claude Code and run:"
echo "  /ship Your task here"
