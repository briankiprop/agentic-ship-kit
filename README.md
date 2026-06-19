# Agentic Ship Kit

A kit that gives Claude Code a structured workflow for building, testing, and reviewing software — so it plans before coding, tests before merging, and never merges without your approval.

**The problem it solves:** When you ask an AI to build something, it often just starts writing code. This kit makes Claude plan the change first, write tests, get your sign-off, then build — like a good engineer would.

---

## How it works

When you type `/ship-skit add a login page`, Claude:

1. **Triages** — decides how much process the request needs (a typo fix needs none; a login feature needs the full pipeline)
2. **Plans** — reads your codebase and writes a plan before touching any code
3. **Shows you the plan** — waits for your approval
4. **Builds** — implements exactly what was approved, on a branch
5. **Tests** — runs your test suite and quality checks
6. **Reviews** — checks the diff against the plan and returns APPROVE / REQUEST CHANGES / BLOCK
7. **Prepares the PR** — you decide when to merge

---

## Choose your install method

There are two ways to use this kit. Pick the one that fits you.

| | Global (recommended for solo devs) | Per-project (recommended for teams) |
|---|---|---|
| **Install once?** | Yes — works in every project | No — install per project |
| **Team can share config?** | No | Yes — committed to git |
| **Files added to project?** | Only `.agent-runs/` (gitignored) | `.claude/`, `scripts/`, `templates/`, `AGENTS.md`, `CLAUDE.md` |
| **Command to use** | `/ship-skit` | `/ship` (also `/ship-skit` if global installed too) |
| **Customise per project?** | Via project `.claude/` overrides | Full control |

---

## Option A — Global install (solo developers)

**Do this once on your machine.** After this, open any project and start shipping.

**macOS / Linux / Git Bash / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.ps1 | iex
```

This installs the kit into `~/.claude/` (your personal Claude Code folder). Nothing is added to your projects.

### How to use it

Open any project in Claude Code and type:

```
/ship-skit add a login page with email and password
```

That's it. Claude will plan, build, test, and review the change. The only thing added to your project is a `.agent-runs/` folder that tracks the work in progress (it's gitignored automatically once you run `/ship-skit` for the first time).

### Update

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap-global.sh | bash -s -- --update
```

### Uninstall

```bash
bash ~/.claude/skills/ship-skit/../../../scripts/uninstall.sh --global
```

Or manually delete `~/.claude/skills/ship-skit/`, `~/.claude/agents/`, and `~/.claude/rules/`.

---

## Option B — Per-project install (teams)

### Install into an existing project

**Do this inside each project you want the kit in.** The kit files are committed to git so the whole team shares the same workflow.

**macOS / Linux / Git Bash / WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.ps1 | iex
```

> **Windows note:** The workflow runs bash scripts at runtime. You need **Git Bash** or **WSL** installed to run the workflow. The PowerShell installer only places the files.

### How to use it

Open the project in Claude Code and type:

```
/ship add a login page with email and password
```

Both `/ship` (project) and `/ship-skit` (if also installed globally) work. Project rules always take precedence over global ones.

### Update

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash -s -- --update
```

### Uninstall

```bash
bash scripts/uninstall.sh
```

---

## All commands at a glance

Type these in the **Claude Code terminal** (the chat input inside Claude Code):

### Shipping work
| Command | What it does |
| --- | --- |
| `/ship-skit <task>` | Start a task — plan, build, test, review (global install) |
| `/ship <task>` | Same, but for per-project install |
| `continue` | Resume a task after a session ends or context fills |
| `/context-handoff` | Save progress before ending a long session |
| `/resume-work` | Resume from saved progress in a new session |

### Telegram setup (run these from the Claude terminal, not a shell)
| Command | What it does |
| --- | --- |
| `/ship-kit-setup` | First-time setup — connect Telegram bot, register this project, start the listener |
| `/ship-kit-reset` | Update credentials, re-register a moved project, or restart the listener |
| `/ship-kit-remove` | Deregister this project from Telegram (optionally stop the listener) |

### Telegram bot commands (send these inside your Telegram chat)
| Command | What it does |
| --- | --- |
| `/ship <project> <task>` | Start a task remotely, e.g. `/ship my-app add login page` |
| `/status` | Check if a task is running or a plan is waiting for approval |
| `/projects` | List all registered projects |
| `/stop` | Stop the currently running task |
| `/approve` | Approve the plan Claude sent — coding begins |
| `/reject` | Cancel the task |
| `/feedback <notes>` | Approve with changes, e.g. `/feedback make it two columns` |
| `/help` | Show all available Telegram commands |

---

## How to use the workflow

Here is exactly what happens when you run `/ship-skit add a login page`:

**Step 1 — Triage.** Claude reads your request and classifies it:
- Tiny fix (typo, comment) → does it inline, no planning needed
- Small fix (one file, no auth/payments/DB) → one agent, quick
- Feature or anything touching auth, payments, or the database → full pipeline

**Step 2 — Plan.** Claude reads the relevant parts of your codebase and writes a plan. It does not touch any source files yet.

**Step 3 — You approve.** Claude shows you the goal, the plan, what will be tested, and the risks. **You say yes or no.** No code is written until you approve.

**Step 4 — Build.** Claude creates a branch and implements exactly what was approved. If the plan turns out to be wrong, it stops and asks you — it does not silently change scope.

**Step 5 — Test.** Claude runs your test suite and quality checks (lint, typecheck, security audit — auto-detected for Node, Python, and Rails).

**Step 6 — Review.** Claude checks the diff against the plan and returns one of:
- **APPROVE** — ready to PR
- **REQUEST CHANGES** — something needs fixing (it tells you what)
- **BLOCK** — a serious problem was found (security issue, missing tests, etc.)

**Step 7 — You merge.** Claude prepares the PR title and description. You decide when to merge. Claude never merges automatically.

---

## Resume and context handoff

Claude Code sessions have a context limit. When a session ends (or gets too long), save your progress:

```
/context-handoff
```

In your next session, pick up where you left off:

```
/resume-work
```

or simply:

```
continue
```

Claude reads the saved progress and continues from the next step — no need to re-explain anything.

---

## What gets created in your project

Every task gets a folder like:

```
.agent-runs/2026-06-17-add-login-page/
```

Inside it:

| File | What it contains |
| --- | --- |
| `intent.md` | What you asked for |
| `plan.md` | The implementation plan |
| `test-plan.md` | What will be tested and how |
| `implementation-log.md` | What was changed and why |
| `test-report.md` | Test results |
| `review-report.md` | Review decision and notes |
| `merge-checklist.md` | Pre-PR checklist |
| `status.md` | Current phase (used to resume) |
| `handoff.md` | Summary for a new session |

These folders are gitignored — they stay local to you.

---

## What each agent does

| Agent | Role | Can edit code? |
| --- | --- | --- |
| `design` | Reads codebase, writes `plan.md` and `test-plan.md` | No |
| `coder` | Implements the approved plan on a branch | Yes |
| `verify` | Runs tests, reviews diff, returns APPROVE / REQUEST CHANGES / BLOCK | No |
| `builder` | Fast path for small changes — plan + build + test in one pass | Yes |

---

## Recovering when something goes wrong

| What happened | What to do |
| --- | --- |
| Reviewer said REQUEST CHANGES | Tell the coder what to fix. Do not redo planning. |
| Reviewer said BLOCK | Fix the problem, then re-run verify. |
| Coder stopped halfway | Say `continue` — it picks up where it left off. |
| Tests failed | Fix the code or tests, then re-run verify only. |
| Plan was wrong | Stop, update `plan.md`, get re-approval, resume coder. |
| Need to redo a specific step | Say which step, e.g. `re-run phase 5 testing`. |

---

## Team collaboration

- **Commit** `.claude/`, `scripts/`, `templates/`, `AGENTS.md`, and `CLAUDE.md` so every team member gets the same workflow on a fresh clone.
- **Do not commit** `.agent-runs/` — each person's run folders are local (already gitignored).
- **One person per run** — two people should not drive the same run folder at the same time. Each person works on their own branch.
- **Personal overrides** — put your personal permission settings in `.claude/settings.local.json` (gitignored) so they don't overwrite shared team settings.

---

## CI/CD integration

The kit does not auto-trigger from CI — `/ship-skit` is an interactive, human-approved workflow. But you can run the quality gates in CI independently:

```yaml
- name: Run quality gates
  run: bash scripts/run-quality-gates.sh
```

`run-quality-gates.sh` auto-detects Node, Python, and Rails and runs the right checks. For monorepos, set `QG_ROOTS`:

```yaml
- run: QG_ROOTS="apps/web apps/api" bash scripts/run-quality-gates.sh
```

---

## Customise for your project

After installing, update these files to match your project's actual commands:

| What to change | File |
| --- | --- |
| Your test/lint commands | `AGENTS.md` |
| Claude-specific behaviour | `CLAUDE.md` |
| Security rules | `.claude/rules/security.md` |
| Permission controls | `.claude/settings.json` |

For example, change `npm test` to your real commands:

```bash
pnpm lint && pnpm typecheck && pnpm test && pnpm test:e2e
```

See [docs/extending.md](docs/extending.md) for how to add custom agents, skills, and rules.

---

## Remote control options

You have three ways to control the kit remotely. Use whichever fits your setup.

### Option 1 — Claude app (simplest, no setup)

The **Claude web app** ([claude.ai](https://claude.ai)) and the **Claude mobile app** (iOS / Android) both support skills and agents. If you have the kit installed globally (Option A above), you can open claude.ai or the mobile app, switch to a project or start a conversation, and use `/ship-skit` exactly as you would in the CLI.

- No extra setup needed
- Works on any device with a browser or the app
- Plan approval, feedback, and task control all happen in the chat
- Skills, rules, and agents in `~/.claude/` are available to Claude Code sessions connected to your machine

This is the recommended first option if you just want to kick off tasks or approve plans while away from your desk.

### Option 2 — Telegram bot (best for background tasks)

Connect the kit to Telegram so it notifies you as tasks progress and lets you approve plans, stop tasks, or start new ones — all from your phone. Best when you want the task running fully in the background on your PC while you're away.

### Step 1 — Create a Telegram bot (5 minutes)

1. Open Telegram and message **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the bot token it gives you (looks like `123456:ABCdef...`)
4. Message **@userinfobot** to get your chat ID (a number)

### Step 2 — Run setup from the Claude terminal

Open any project in Claude Code and type:

```
/ship-kit-setup
```

Claude will guide you through the whole setup interactively — no bash commands needed:

1. Asks you to paste the bot token and chat ID
2. Tests the connection and sends a confirmation to Telegram
3. Registers the current project automatically
4. Starts the background listener

Nothing is committed to git — credentials are saved in `~/.agentic-ship-telegram` on your machine only.

> **Alternative (manual):** If you prefer the command line, run `bash scripts/setup-telegram.sh` and then `bash scripts/register-project.sh /path/to/project alias`.

### What you get

As Claude works through the task you get Telegram messages at each phase:

| When | Message |
| --- | --- |
| Task starts | "Starting task on my-app" |
| Planning | "Planning..." |
| Writing code | "Writing code..." |
| Running tests | "Running tests..." |
| Plan ready for review | Full plan text sent — reply `/approve`, `/reject`, or `/feedback <notes>` |
| Review complete | "Review: APPROVE" or "Review: REQUEST CHANGES" or "Review: BLOCK" |
| Task complete | Summary of what was done |
| Needs clarification | Claude's question forwarded — reply `/ship my-app <clarified task>` |
| Stopped or interrupted | "Task was stopped or interrupted" |

### Step 3 — Register more projects

For each additional project, open it in Claude Code and run:

```
/ship-kit-setup
```

It detects that credentials are already saved and skips straight to registering the new project.

> **Alternative:** `bash scripts/register-project.sh /path/to/my-api my-api`

### Telegram commands

Once the listener is running, send these from your bot:

```
/ship my-app add a login page with email and password
/ship my-api fix the checkout bug
/projects                          ← list registered projects
/status                            ← check if a task is running (or if a plan needs approval)
/stop                              ← stop the current task

/approve                           ← approve the plan, start coding
/reject                            ← cancel the task
/feedback make it two columns      ← approve with changes, then code
```

Claude runs the task entirely in the background. When the plan is ready, the bot sends you the full plan and waits — reply directly in Telegram. No need to open Claude Code on your PC.

### Managing your setup

| Need | Command |
| --- | --- |
| Update bot token or chat ID | `/ship-kit-reset` in Claude terminal |
| Re-register a project (moved or renamed) | `/ship-kit-reset` in Claude terminal |
| Restart the listener | `/ship-kit-reset` in Claude terminal |
| Remove a project from Telegram | `/ship-kit-remove` in Claude terminal |

### Auto-resume when context fills up

If Claude's context fills during a long task, `run-headless.sh` automatically retries with `claude --continue` up to 5 times. You don't need to do anything — it picks up from where it left off using `status.md` and `handoff.md`.

### Run a task directly without Telegram

```bash
bash scripts/run-headless.sh "add a login page" /path/to/my-app
```

Logs go to `~/.agentic-ship-runs/`.

---

## Troubleshooting

### Nothing happens when I type `/ship-skit`

Make sure you installed the kit globally (Option A). Check that `~/.claude/skills/ship-skit/SKILL.md` exists.

### `checkpoint.sh` errors

The Stop hook logs errors to `.agent-runs/checkpoint.log`. Check that file. You can also run it manually: `bash scripts/checkpoint.sh`

### Python not found on Windows

On Windows Git Bash, `python3` may be a stub. The scripts try `python3` then `python` automatically. Install Python from [python.org](https://www.python.org) if both fail.

### The run folder points to a missing directory

Update `.agent-runs/latest-run.txt` to point to an existing folder, or let the next `/ship-skit` create a fresh run.

### Agent created commits on `main`

Create a branch and move the commits:

```bash
git checkout -b agent/my-task
git branch -f main HEAD~1
```

---

## Safety rules

The kit enforces five rules that cannot be bypassed:

1. **Plan before coding** — no source files change until a plan exists
2. **Test design before coding** — tests are planned before the coder starts
3. **Human approval before coding** — Claude waits for your yes
4. **Honest test results** — Claude never claims tests passed unless they actually ran and passed
5. **Human merges** — Claude prepares the PR but never merges automatically

---

## Repository layout

```
agentic-ship-kit/
├── .claude/
│   ├── agents/          ← AI agents (planner, coder, tester, reviewer, ...)
│   ├── rules/           ← Security, testing, git, coding standards
│   ├── settings.json    ← Permission defaults
│   └── skills/
│       ├── ship/            ← /ship (per-project)
│       ├── ship-skit/       ← /ship-skit (global)
│       ├── ship-kit-setup/  ← /ship-kit-setup (Telegram setup)
│       ├── ship-kit-reset/  ← /ship-kit-reset (update config)
│       ├── ship-kit-remove/ ← /ship-kit-remove (deregister project)
│       └── ...
├── docs/
│   └── extending.md     ← How to add custom agents, skills, rules
├── scripts/
│   ├── bootstrap.sh           ← Per-project installer
│   ├── bootstrap-global.sh    ← Global installer
│   ├── install.sh             ← Per-project install logic
│   ├── install-global.sh      ← Global install logic
│   ├── update.sh              ← Update per-project or global
│   ├── uninstall.sh           ← Remove per-project or global
│   └── run-quality-gates.sh   ← Auto-detected quality checks
├── templates/           ← Artifact templates (plan, rollback, etc.)
├── AGENTS.md            ← Shared rules for all agents
├── CLAUDE.md            ← Claude Code entrypoint
└── README.md
```
