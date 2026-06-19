---
name: ship-kit-remove
description: Remove Agentic Ship Kit configuration for the current project — deregisters the project, optionally removes Telegram credentials, and stops the listener.
argument-hint: ""
---

# ship-kit-remove

Remove the Agentic Ship Kit configuration for the current project. This does not uninstall the kit files — it only removes the runtime config entries for this folder.

## Step 1 — Show what will be removed

```bash
PROJECT_DIR="$PWD"
ALIAS="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

echo "Current project: $PROJECT_DIR"
echo "Alias: $ALIAS"
echo ""

echo "=== Registered projects ==="
cat "$HOME/.agentic-ship-projects" 2>/dev/null || echo "None."

echo ""
echo "=== Poller ==="
if [ -f "$HOME/.agentic-ship-poller.pid" ]; then
  PID="$(cat "$HOME/.agentic-ship-poller.pid")"
  kill -0 "$PID" 2>/dev/null && echo "Running (PID $PID)" || echo "Not running"
else
  echo "Not running."
fi

echo ""
echo "=== Telegram config ==="
[ -f "$HOME/.agentic-ship-telegram" ] && echo "Exists (~/.agentic-ship-telegram)" || echo "Not found."
```

## Step 2 — Deregister current project

Remove this project's entry from `~/.agentic-ship-projects`:

```bash
PROJECT_DIR="$PWD"
ALIAS="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

if [ -f "$HOME/.agentic-ship-projects" ]; then
  # Remove by path match (handles alias mismatches too)
  grep -v "=${PROJECT_DIR}$" "$HOME/.agentic-ship-projects" \
  | grep -v "^${ALIAS}=" \
  > "$HOME/.agentic-ship-projects.tmp" 2>/dev/null || true
  mv "$HOME/.agentic-ship-projects.tmp" "$HOME/.agentic-ship-projects"
  echo "Removed: $ALIAS"
else
  echo "No projects file found — nothing to remove."
fi
```

## Step 3 — Check remaining projects

```bash
REMAINING="$(cat "$HOME/.agentic-ship-projects" 2>/dev/null | grep -v '^\s*$' | wc -l)"
echo "Remaining registered projects: $REMAINING"
cat "$HOME/.agentic-ship-projects" 2>/dev/null || true
```

## Step 4 — Offer to remove Telegram credentials

If no projects remain, or if the user explicitly wants to remove them, ask:

> No other projects are registered. Do you also want to remove the Telegram bot credentials (`~/.agentic-ship-telegram`)? This will disconnect all Telegram notifications until you run `/ship-kit-setup` again.

If yes:

```bash
rm -f "$HOME/.agentic-ship-telegram"
rm -f "$HOME/.agentic-ship-telegram-offset"
echo "Removed Telegram credentials."
```

If projects remain, skip this step unless the user explicitly asks.

## Step 5 — Stop the poller

Ask: "Do you also want to stop the background listener?"

If yes (or if no projects remain):

```bash
if [ -f "$HOME/.agentic-ship-poller.pid" ]; then
  PID="$(cat "$HOME/.agentic-ship-poller.pid")"
  kill "$PID" 2>/dev/null && echo "Stopped PID $PID" || echo "Process already gone"
  rm -f "$HOME/.agentic-ship-poller.pid"
else
  echo "Poller was not running."
fi
```

## Step 6 — Confirm

Print a summary:

```
Removed:
  Project: <alias> deregistered
  Telegram credentials: removed / kept
  Poller: stopped / still running

To re-add this project later, run /ship-kit-setup from this folder.
```

If the kit files themselves (`.claude/`, `scripts/`, etc.) should also be removed, tell the user to run `bash scripts/uninstall.sh` for a full uninstall.
