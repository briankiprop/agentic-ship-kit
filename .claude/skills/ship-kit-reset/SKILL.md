---
name: ship-kit-reset
description: Re-configure Agentic Ship Kit for the current project — update Telegram credentials, re-register the project path, or restart the listener. Use when credentials change or the project was moved.
argument-hint: ""
---

# ship-kit-reset

Reset or update parts of the Agentic Ship Kit configuration without starting from scratch. Show the current state first, then ask what to change.

## Step 1 — Show current configuration

Read and display the current state:

```bash
echo "=== Telegram config ==="
if [ -f "$HOME/.agentic-ship-telegram" ]; then
  TOKEN="$(grep 'TELEGRAM_BOT_TOKEN' "$HOME/.agentic-ship-telegram" | cut -d= -f2 | tr -d '"')"
  CHAT_ID="$(grep 'TELEGRAM_CHAT_ID' "$HOME/.agentic-ship-telegram" | cut -d= -f2 | tr -d '"')"
  echo "Token:   ${TOKEN:0:10}..."
  echo "Chat ID: $CHAT_ID"
else
  echo "Not configured."
fi

echo ""
echo "=== Registered projects ==="
cat "$HOME/.agentic-ship-projects" 2>/dev/null || echo "None registered."

echo ""
echo "=== Poller ==="
if [ -f "$HOME/.agentic-ship-poller.pid" ]; then
  PID="$(cat "$HOME/.agentic-ship-poller.pid")"
  kill -0 "$PID" 2>/dev/null && echo "Running (PID $PID)" || echo "Not running (stale PID $PID)"
else
  echo "Not running."
fi

echo ""
echo "=== Current project ==="
echo "$PWD"
ALIAS="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
if grep -qF "=$PWD" "$HOME/.agentic-ship-projects" 2>/dev/null; then
  echo "Registered as: $ALIAS"
else
  echo "Not registered."
fi
```

## Step 2 — Ask what to reset

Ask the user which parts to update. Present the options clearly:

> What would you like to reset?
>
> 1. **Telegram credentials** — enter a new bot token and/or chat ID
> 2. **Re-register this project** — update the alias or path for the current folder
> 3. **Restart the poller** — stop and restart the background listener
> 4. **All of the above**

Wait for the user's choice, then apply only the selected changes.

## Option 1 — Reset Telegram credentials

Ask the user to paste the new bot token and/or chat ID. Keep whichever values they don't want to change.

```bash
source "$HOME/.agentic-ship-telegram" 2>/dev/null || true
# Use existing values as defaults if user skips
NEW_TOKEN="${NEW_TOKEN:-$TELEGRAM_BOT_TOKEN}"
NEW_CHAT_ID="${NEW_CHAT_ID:-$TELEGRAM_CHAT_ID}"

cat > "$HOME/.agentic-ship-telegram" <<EOF
# Agentic Ship Kit — Telegram config
# Keep this file private — it contains your bot token.
TELEGRAM_BOT_TOKEN="$NEW_TOKEN"
TELEGRAM_CHAT_ID="$NEW_CHAT_ID"
EOF
chmod 600 "$HOME/.agentic-ship-telegram"
```

Test the new credentials:

```bash
source "$HOME/.agentic-ship-telegram"
RESPONSE="$(curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=Agentic Ship Kit — credentials updated successfully." \
  2>&1)"
echo "$RESPONSE"
```

If `"ok":true` — confirm saved. Otherwise show the error.

## Option 2 — Re-register current project

```bash
PROJECT_DIR="$PWD"
ALIAS="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"

# Remove all existing entries for this path or alias
if [ -f "$HOME/.agentic-ship-projects" ]; then
  grep -v "^${ALIAS}=" "$HOME/.agentic-ship-projects" \
  | grep -v "=${PROJECT_DIR}$" \
  > "$HOME/.agentic-ship-projects.tmp" 2>/dev/null || true
  mv "$HOME/.agentic-ship-projects.tmp" "$HOME/.agentic-ship-projects"
fi

echo "${ALIAS}=${PROJECT_DIR}" >> "$HOME/.agentic-ship-projects"
chmod 600 "$HOME/.agentic-ship-projects"
echo "Re-registered: $ALIAS -> $PROJECT_DIR"
```

## Option 3 — Restart the poller

Stop any running instance:

```bash
if [ -f "$HOME/.agentic-ship-poller.pid" ]; then
  PID="$(cat "$HOME/.agentic-ship-poller.pid")"
  kill "$PID" 2>/dev/null || true
  rm -f "$HOME/.agentic-ship-poller.pid"
  echo "Stopped PID $PID"
fi
```

Then start a fresh instance using the same Python detection logic from `/ship-kit-setup` Step 5. Find `poll-telegram.py` and launch it.

## Step 3 — Confirm

After applying changes, print a brief summary of what was updated and what stayed the same. If credentials were changed, confirm the Telegram test succeeded.
