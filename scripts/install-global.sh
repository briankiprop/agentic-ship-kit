#!/usr/bin/env bash
# Install Agentic Ship Kit globally into ~/.claude/
#
# After running this, open any project in Claude Code and use:
#   /ship-skit Your task here
#
# Nothing is copied into your project — the kit runs entirely from ~/.claude/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GLOBAL_DIR="${CLAUDE_HOME:-$HOME/.claude}"

echo "Installing Agentic Ship Kit globally into: $GLOBAL_DIR"

backup_and_copy() {
  local src="$ROOT/$1"
  local dest="$GLOBAL_DIR/$2"
  if [ -e "$dest" ]; then
    backup="$dest.agentic-ship-backup.$(date +%Y%m%d%H%M%S)"
    echo "  Backing up existing $dest → $backup"
    mv "$dest" "$backup"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
  echo "  Installed $2"
}

# Install the ship-skit global skill
backup_and_copy ".claude/skills/ship-skit" "skills/ship-skit"

# Install all agents
backup_and_copy ".claude/agents" "agents"

# Install all rules
backup_and_copy ".claude/rules" "rules"

echo ""
echo "Done! The kit is now available in every project you open in Claude Code."
echo ""
echo "How to use it:"
echo "  1. Open any project in Claude Code"
echo "  2. Type:  /ship-skit Your task here"
echo "  3. Example: /ship-skit add a login page with email and password"
echo ""
echo "No files will be added to your project except a .agent-runs/ folder"
echo "that tracks your work in progress (already gitignored if you use the kit)."
