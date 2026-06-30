---
name: ship-global
description: Global /ship alias — routes to per-project /ship if installed, otherwise runs the global ship-skit workflow.
argument-hint: "[what you want to build or fix]"
disable-model-invocation: true
---

# Ship (Global Alias)

This skill gives global-install users the same `/ship` command that per-project users have.

## Routing logic

**Step 1 — Check for per-project install:**

Run this check:
```bash
test -f ".claude/skills/ship/SKILL.md" && echo "per-project" || echo "global"
```

**Step 2a — Per-project install found:**

The project has its own `/ship` skill. Read `.claude/skills/ship/SKILL.md` and follow those
instructions exactly. The per-project skill has project-specific rules, quality gates, and
settings that take precedence over everything global.

**Step 2b — No per-project install:**

Follow the full `/ship-skit` workflow below. The global skill handles everything.

---

## Global ship-skit workflow

If the user said "continue", "resume", or "go to phase 2" — do not start over.
Read `.agent-runs/latest-run.txt`, then that run's `status.md` and `handoff.md`, then
continue from the next unchecked phase.

If context is close to the limit, save progress first:
- Update `status.md` and `handoff.md` with current phase and next step
- Tell the user to start a new session and say `continue`

---

## Step 0: First-run bootstrap

Before triaging, check whether this project has been bootstrapped for global-install use.

```bash
test -d ".agent-runs" && echo "bootstrapped" || echo "fresh"
```

**If fresh (no `.agent-runs/` directory):** Run the bootstrap silently before proceeding:

```bash
# 1. Create the runs directory
mkdir -p .agent-runs

# 2. Add gitignore entries if not already present
GITIGNORE=".gitignore"
MARKER="# agentic-ship-kit"
if [ ! -f "$GITIGNORE" ] || ! grep -qF "$MARKER" "$GITIGNORE"; then
  printf '\n%s\n.agent-runs/\n.ship-context/\n.ship-context-cache/\n.ship_context_*.json\n.mcp.json\n' "$MARKER" >> "$GITIGNORE"
fi

# 3. Write .mcp.json if not present
if [ ! -f ".mcp.json" ]; then
  GLOBAL_SCRIPTS="$HOME/.claude/scripts"
  # Detect python command
  PY_CMD="python"
  command -v python3 >/dev/null 2>&1 && PY_CMD="python3"
  cat > .mcp.json <<MCPEOF
{
  "mcpServers": {
    "ship-context": {
      "command": "$PY_CMD",
      "args": ["$GLOBAL_SCRIPTS/context_server.py"],
      "env": {}
    }
  }
}
MCPEOF
fi

# 4. Wire post-commit hook if in a git repo
HOOKS_DIR=".git/hooks"
if [ -d "$HOOKS_DIR" ]; then
  POST_COMMIT="$HOOKS_DIR/post-commit"
  HOOK_MARKER="# ship-kit-hook"
  if [ ! -f "$POST_COMMIT" ] || ! grep -qF "$HOOK_MARKER" "$POST_COMMIT"; then
    printf '\n%s\nbash "%s/scripts/post-commit.sh" 2>/dev/null || bash "%s/.claude/scripts/post-commit.sh" 2>/dev/null || true\n' \
      "$HOOK_MARKER" "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" "$HOME" >> "$POST_COMMIT"
    chmod +x "$POST_COMMIT"
  fi
fi

# 5. Prime the context cache
bash "$HOME/.claude/scripts/build-context.sh" "$PWD" >/dev/null 2>&1 || true
```

After bootstrap, continue with triage below.

---

## Step 1: Triage

Decide how much process this change needs. Apply rules top to bottom — first match wins.

**Rule 1 — Always full pipeline if the change touches:**
- Login, logout, signup, passwords, tokens, sessions, OAuth, permissions, roles
- Payments, billing, checkout, refunds, pricing
- Database tables, columns, indexes, migrations
- Encryption, secrets, file uploads, security checks

**Rule 2 — Trivial** (no agents needed, do it inline):
- Fixing a typo or comment
- Updating docs or a README
- Changing formatting

**Rule 3 — Small** (one fast agent):
- A bug fix in one file that does not touch Rule 1 areas
- A small feature in one file

**Rule 4 — Large** (full pipeline):
- Everything else, and anything where you are not sure

Tell the user which tier and why. Example: `Tier: large — touches login (Rule 1)`.

---

## Step 2: Create the run folder

```bash
SLUG="$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | head -c 40 | sed 's/-$//')"
RUN_ID="$(date +%Y-%m-%d)-$SLUG"
mkdir -p ".agent-runs/$RUN_ID"
echo ".agent-runs/$RUN_ID" > .agent-runs/latest-run.txt
```

Create inside the run folder: `intent.md`, `plan.md`, `test-plan.md`, `implementation-log.md`,
`test-report.md`, `review-report.md`, `merge-checklist.md`, `status.md`, `handoff.md`.

If the project has `scripts/create-run.sh`, use it instead:
```bash
bash scripts/create-run.sh "Your task description"
```

---

## Tier: Trivial
Make the change inline. No agents. No run folder. Work on a branch, never on main.

---

## Tier: Small
1. Create run folder (Step 2).
2. Invoke the `builder` agent.
3. Run `/release-check` and prepare the PR.
4. Never merge to main.

---

## Tier: Large — Full pipeline

```
Your request → design → You approve → coder → verify → release check → You merge
```

### Design
Invoke the `design` agent. It reads your codebase, writes `plan.md` and `test-plan.md`.
Does NOT touch source files.

**Project rules:** If `AGENTS.md` exists in the project root, the design agent reads it.
If not, it uses `~/.claude/rules/` built-in rules.

### Approval
Show the user: goal, plan summary, what will be tested, biggest risks, files likely to change.
**Wait for yes before any code is written.**

### Coder
Invoke the `coder` agent. Creates a branch, implements the approved plan, adds/updates tests,
writes `implementation-log.md`. If the plan is wrong, stops and asks for re-approval.

### Verify
Invoke the `verify` agent. Runs tests + quality gates, reviews the diff, writes `test-report.md`
and `review-report.md`. Returns: **APPROVE**, **REQUEST CHANGES**, or **BLOCK**.

### Release check
Use `/release-check` before opening a PR. Never merge directly to main.

---

## Phase recovery

| What happened | What to do |
| --- | --- |
| Reviewer said REQUEST CHANGES | Give feedback to `coder`. Do not redo planning. |
| Reviewer said BLOCK | Fix the issue, re-run `verify`. |
| Coder stopped halfway | Say `continue`. |
| Tests failed | Fix, then re-run `verify` only. |
| Plan was wrong | Stop, update `plan.md`, get re-approval, resume `coder`. |

---

## Saving progress

Before context gets too large:
1. Update `status.md` with current phase.
2. Update `handoff.md` (200–400 words: what's done, what's next, key decisions, risks).
3. Tell the user: "Start a new Claude Code session and say `continue`."
