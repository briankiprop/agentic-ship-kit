#!/usr/bin/env bash
# Register a project so it can be triggered by name from Telegram.
#
# Usage:
#   bash scripts/register-project.sh /path/to/my-app my-app
#   bash scripts/register-project.sh /path/to/my-app        # uses folder name as alias
#
# After registering, trigger tasks from Telegram:
#   /ship my-app add a login page
#
# Projects list is saved to ~/.agentic-ship-projects
set -euo pipefail

PROJECTS_FILE="$HOME/.agentic-ship-projects"

PROJECT_PATH="${1:-}"
ALIAS="${2:-}"

if [ -z "$PROJECT_PATH" ]; then
  echo "Usage: bash scripts/register-project.sh /path/to/project [alias]" >&2
  echo ""
  echo "Registered projects:"
  if [ -f "$PROJECTS_FILE" ]; then
    cat "$PROJECTS_FILE"
  else
    echo "  (none yet)"
  fi
  exit 0
fi

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)" || {
  echo "Directory not found: $1" >&2
  exit 1
}

# Default alias to folder name
if [ -z "$ALIAS" ]; then
  ALIAS="$(basename "$PROJECT_PATH")"
fi

# Validate alias (letters, numbers, hyphens only)
if ! echo "$ALIAS" | grep -qE '^[a-zA-Z0-9_-]+$'; then
  echo "Alias must contain only letters, numbers, hyphens, and underscores." >&2
  exit 1
fi

# Remove existing entry for this alias or path (avoid duplicates)
if [ -f "$PROJECTS_FILE" ]; then
  TMP="$(mktemp)"
  grep -v "^${ALIAS}=" "$PROJECTS_FILE" | grep -v "=${PROJECT_PATH}$" > "$TMP" || true
  mv "$TMP" "$PROJECTS_FILE"
fi

# Append new entry
echo "${ALIAS}=${PROJECT_PATH}" >> "$PROJECTS_FILE"
chmod 600 "$PROJECTS_FILE"

echo "Registered: $ALIAS → $PROJECT_PATH"
echo ""
echo "From Telegram, trigger tasks with:"
echo "  /ship $ALIAS add a login page"
echo "  /ship $ALIAS fix the checkout bug"
echo ""
echo "All registered projects:"
cat "$PROJECTS_FILE"
