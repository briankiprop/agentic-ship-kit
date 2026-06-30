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

# Install skills: ship-skit (global workflow), ship (alias), and management skills
backup_and_copy ".claude/skills/ship-skit" "skills/ship-skit"
backup_and_copy ".claude/skills/ship-global" "skills/ship"
backup_and_copy ".claude/skills/ship-kit-setup" "skills/ship-kit-setup"
backup_and_copy ".claude/skills/ship-kit-reset" "skills/ship-kit-reset"
backup_and_copy ".claude/skills/ship-kit-remove" "skills/ship-kit-remove"
backup_and_copy ".claude/skills/context-handoff" "skills/context-handoff"
backup_and_copy ".claude/skills/resume-work" "skills/resume-work"
backup_and_copy ".claude/skills/plan-change" "skills/plan-change"
backup_and_copy ".claude/skills/test-change" "skills/test-change"
backup_and_copy ".claude/skills/review-change" "skills/review-change"
backup_and_copy ".claude/skills/release-check" "skills/release-check"

# Install all agents
backup_and_copy ".claude/agents" "agents"

# Install all rules
backup_and_copy ".claude/rules" "rules"

# Install scripts (checkpoint, notify-telegram, build-context, post-commit, check-drift)
# Strip CRLF line endings so bash heredocs work correctly on Windows-authored files.
mkdir -p "$GLOBAL_DIR/scripts"
for script in checkpoint.sh notify-telegram.sh build-context.sh post-commit.sh check-drift.sh context_server.py; do
  src="$ROOT/scripts/$script"
  dest="$GLOBAL_DIR/scripts/$script"
  if [ -f "$src" ]; then
    if command -v sed >/dev/null 2>&1; then
      # Strip CRLF so bash heredocs work correctly on Windows-authored files.
      sed 's/\r//' "$src" > "$dest"
    else
      cp "$src" "$dest"
    fi
    chmod +x "$dest" 2>/dev/null || true
    echo "  Installed scripts/$script"
  fi
done

# Install templates
mkdir -p "$GLOBAL_DIR/templates"
for tpl in handoff.md implementation-log.md intent.md merge-checklist.md phase-comment.md plan.md review-report.md rollback.md status.md test-plan.md test-report.md; do
  src="$ROOT/templates/$tpl"
  dest="$GLOBAL_DIR/templates/$tpl"
  if [ -f "$src" ]; then
    cp "$src" "$dest"
    echo "  Installed templates/$tpl"
  fi
done

# Write global CLAUDE.md (injects AGENTS.md rules into every Claude Code session)
GLOBAL_CLAUDE="$GLOBAL_DIR/CLAUDE.md"
if [ ! -f "$GLOBAL_CLAUDE" ]; then
  cp "$ROOT/templates/global-CLAUDE.md" "$GLOBAL_CLAUDE"
  echo "  Installed CLAUDE.md"
else
  echo "  CLAUDE.md already exists — skipping (run with --force to overwrite)"
fi

# Write global AGENTS.md
GLOBAL_AGENTS="$GLOBAL_DIR/AGENTS.md"
if [ ! -f "$GLOBAL_AGENTS" ]; then
  cp "$ROOT/AGENTS.md" "$GLOBAL_AGENTS"
  echo "  Installed AGENTS.md"
else
  echo "  AGENTS.md already exists — skipping"
fi

# Write global settings.json (hooks + permissions)
GLOBAL_SETTINGS="$GLOBAL_DIR/settings.json"
if [ ! -f "$GLOBAL_SETTINGS" ]; then
  cp "$ROOT/templates/global-settings.json" "$GLOBAL_SETTINGS"
  echo "  Installed settings.json"
else
  echo "  settings.json already exists — skipping (run with --force to overwrite)"
fi

# Write global .mcp.json (context server registration)
GLOBAL_MCP="$GLOBAL_DIR/.mcp.json"
SCRIPTS_ABS="$(cd "$GLOBAL_DIR/scripts" && pwd)"
# Detect python command on this machine
PY_CMD="python"
command -v python3 >/dev/null 2>&1 && PY_CMD="python3"
if [ ! -f "$GLOBAL_MCP" ]; then
  sed "s|GLOBAL_SCRIPTS_DIR|$SCRIPTS_ABS|g" "$ROOT/templates/global-mcp.json" | \
    sed "s|\"python\"|\"$PY_CMD\"|g" > "$GLOBAL_MCP"
  echo "  Installed .mcp.json (context server: $SCRIPTS_ABS/context_server.py)"
else
  echo "  .mcp.json already exists — skipping"
fi

echo ""
echo "Done! The kit is now available in every project you open in Claude Code."
echo ""
echo "How to use it:"
echo "  1. Open any project in Claude Code"
echo "  2. Type:  /ship-skit Your task here"
echo "     or:    /ship Your task here"
echo "  3. Example: /ship add a login page with email and password"
echo ""
echo "On first run in a new project, the kit will automatically:"
echo "  - Create .agent-runs/ for progress tracking"
echo "  - Update .gitignore so those files stay local"
echo "  - Register the context cache server"
echo "  - Wire the post-commit hook for auto-refresh"
echo ""
echo "Nothing is committed to your project. All kit files stay in ~/.claude/"
