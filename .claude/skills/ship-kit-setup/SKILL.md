---
name: ship-kit-setup
description: Interactive setup for Agentic Ship Kit — configures Telegram bot credentials, registers the current project, and starts the background listener. Run once per machine, then again for each new project.
argument-hint: ""
---

# ship-kit-setup

Set up the Agentic Ship Kit so you can control Claude tasks from Telegram. Walk through each step below in order. Use Bash tool calls throughout — do not ask the user to run commands themselves.

## Step 1 — Check what is already configured

Run these checks silently and remember the results:

```bash
# Telegram credentials
cat "$HOME/.agentic-ship-telegram" 2>/dev/null || echo "NOT_CONFIGURED"

# Registered projects
cat "$HOME/.agentic-ship-projects" 2>/dev/null || echo "NONE"

# Current project
echo "$PWD"
ALIAS="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
echo "alias: $ALIAS"

# Poller running?
cat "$HOME/.agentic-ship-poller.pid" 2>/dev/null || echo "NO_POLLER"
```

Tell the user what is already done and what still needs to be set up. If everything is already configured and working, say so and offer to re-run any step.

## Step 2 — Telegram credentials

Skip this step if `~/.agentic-ship-telegram` already contains a non-empty `TELEGRAM_BOT_TOKEN`.

Ask the user:

> To set up Telegram notifications, I need two things:
>
> **Bot token** — message @BotFather on Telegram, send `/newbot`, follow the prompts, and paste the token here (looks like `123456:ABCdef...`).
>
> **Chat ID** — message @userinfobot on Telegram and paste the number it replies with.

Wait for the user to paste both values. Then write the config file:

```bash
TOKEN="<pasted token>"
CHAT_ID="<pasted chat id>"

# Strip whitespace
TOKEN="$(echo "$TOKEN" | tr -d '[:space:]')"
CHAT_ID="$(echo "$CHAT_ID" | tr -d '[:space:]')"

cat > "$HOME/.agentic-ship-telegram" <<EOF
# Agentic Ship Kit — Telegram config
# Keep this file private — it contains your bot token.
TELEGRAM_BOT_TOKEN="$TOKEN"
TELEGRAM_CHAT_ID="$CHAT_ID"
EOF
chmod 600 "$HOME/.agentic-ship-telegram"
echo "Saved."
```

Then test the connection:

```bash
source "$HOME/.agentic-ship-telegram"
RESPONSE="$(curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=Agentic Ship Kit connected! Setup is in progress..." \
  2>&1)"
echo "$RESPONSE"
```

If the response contains `"ok":true` — proceed. If not, show the error and ask the user to check the token and chat ID, then retry.

## Step 3 — Register current project

Register the project so it can be targeted with `/ship <alias> <task>` from Telegram.

```bash
PROJECT_DIR="$PWD"
ALIAS="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

# Check if already registered
if grep -qF "=$PROJECT_DIR" "$HOME/.agentic-ship-projects" 2>/dev/null; then
  echo "Already registered as: $(grep "=$PROJECT_DIR" "$HOME/.agentic-ship-projects" | cut -d= -f1)"
else
  # Remove any existing entry with the same alias to avoid duplicates
  if [ -f "$HOME/.agentic-ship-projects" ]; then
    grep -v "^${ALIAS}=" "$HOME/.agentic-ship-projects" > "$HOME/.agentic-ship-projects.tmp" 2>/dev/null || true
    mv "$HOME/.agentic-ship-projects.tmp" "$HOME/.agentic-ship-projects"
  fi
  echo "${ALIAS}=${PROJECT_DIR}" >> "$HOME/.agentic-ship-projects"
  chmod 600 "$HOME/.agentic-ship-projects"
  echo "Registered: $ALIAS -> $PROJECT_DIR"
fi
```

Tell the user: "Your project is registered as **`<alias>`**. From Telegram you can now send: `/ship <alias> your task here`"

## Step 4 — Check Claude Code CLI

```bash
claude --version 2>/dev/null || echo "NOT_FOUND"
```

If not found, tell the user and offer to install:

```bash
npm install -g @anthropic-ai/claude-code
```

Confirm with `claude --version` after installing.

## Step 5 — Find and start the poller

Find `poll-telegram.py`:

```bash
# Check per-project install first
if [ -f "./scripts/poll-telegram.py" ]; then
  echo "FOUND:./scripts/poll-telegram.py"
# Then check global location relative to this skill file's directory
elif [ -f "$HOME/.claude/skills/ship-skit/../../../scripts/poll-telegram.py" ]; then
  echo "FOUND:global"
else
  # Search common locations
  find "$HOME" -name "poll-telegram.py" -maxdepth 8 2>/dev/null | head -3
fi
```

Check if already running:

```bash
if [ -f "$HOME/.agentic-ship-poller.pid" ]; then
  PID="$(cat "$HOME/.agentic-ship-poller.pid")"
  kill -0 "$PID" 2>/dev/null && echo "RUNNING:$PID" || echo "STALE"
else
  echo "NOT_RUNNING"
fi
```

If not running, start it. Use `python3` or `python` (whichever exists) on Unix/Mac. On Windows Git Bash, use the full Python path:

```bash
SCRIPT_PATH="<path to poll-telegram.py>"

# Find Python
PYTHON=""
for candidate in python3 python "C:/Users/$USERNAME/AppData/Local/Programs/Python/Python312/python.exe" "C:/Python312/python.exe"; do
  if command -v "$candidate" >/dev/null 2>&1 || [ -f "$candidate" ]; then
    PYTHON="$candidate"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  echo "Python not found — install Python from https://www.python.org"
else
  rm -f "$HOME/.agentic-ship-poller.pid"
  nohup "$PYTHON" "$SCRIPT_PATH" >> "$HOME/.agentic-ship-runs/poller.log" 2>&1 &
  echo "Started poller PID $!"
fi
```

Wait 3 seconds, then confirm the poller wrote its PID file and a startup message appeared in the log.

## Step 6 — Final confirmation

Send a completion message to Telegram:

```bash
source "$HOME/.agentic-ship-telegram"
ALIAS="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=Setup complete!

Registered project: $ALIAS

Commands you can send here:
/ship $ALIAS <task description>
/status
/stop
/help" \
  >/dev/null 2>&1
```

Print a summary to the Claude terminal:

```
Setup complete!

  Telegram: connected (chat ID: <chat_id>)
  Project:  <alias> -> <path>
  Poller:   running (PID <pid>)

From Telegram, send:
  /ship <alias> add a login page
  /status
  /help
```
