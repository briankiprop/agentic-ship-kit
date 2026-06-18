#!/usr/bin/env bash
# Global one-line installer for the Agentic Ship Kit.
#
# Install (first time — run this once on your machine):
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.sh | bash
#
# Update (already installed globally):
#   curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.sh | bash -s -- --update
#
# After running, open ANY project in Claude Code and type:
#   /ship-skit Your task here
#
# Nothing is added to your project except a .agent-runs/ folder for progress tracking.
set -euo pipefail

REPO="${ASK_REPO:-https://github.com/briankiprop/agentic-ship-kit.git}"
REF="${ASK_REF:-main}"
UPDATE=0

for arg in "$@"; do
  case "$arg" in
    --update) UPDATE=1 ;;
    *) ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found on PATH." >&2
  exit 1
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "Agentic Ship Kit — Source: $REPO@$REF"
git clone --depth 1 --branch "$REF" "$REPO" "$TMP/kit" >/dev/null 2>&1 || {
  echo "Failed to clone $REPO@$REF" >&2
  exit 1
}

bash "$TMP/kit/scripts/install-global.sh"
