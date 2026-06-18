# Agentic Ship Kit

A GitHub-ready Claude Code starter kit for planning, building, testing, reviewing, and handing off software changes with specialized AI agents.

The goal is simple: make AI-assisted coding safer, clearer, and easier to resume.

Instead of asking one agent to do everything, this kit uses a controlled workflow:

```text
Request → Planner → Test Architect → Human Approval → Coder → Tester → Reviewer → Release Check → Human Merge
```

The agents can help you move fast, but they should not secretly skip planning, testing, review, or human approval.

---

## Who this is for

Use this kit if you want Claude Code to help you:

- Build new features
- Fix bugs
- Refactor code
- Add tests
- Review changes before a PR
- Keep a clear audit trail of what happened
- Resume work in a new Claude Code session without rereading the whole project

You do not need to understand every file on day one. Start with `/ship` and the workflow will guide you.

---

## What you get

### Claude Code subagents

Located in `.claude/agents/`:

| Agent | Model | Purpose | Can edit code? |
| --- | --- | --- | --- |
| `planner` | Opus | Understand the request and create the implementation plan | No |
| `test-architect` | Opus | Design tests before coding starts | No |
| `coder` | Sonnet | Implement the approved plan and tests | Yes |
| `tester` | Sonnet | Run checks and write the test report | No |
| `reviewer` | Opus | Review the final diff against the plan and test results | No |

### Claude Code skills

Located in `.claude/skills/`:

| Skill | Use it for |
| --- | --- |
| `/ship` | Full end-to-end workflow |
| `/plan-change` | Planning only |
| `/test-change` | Testing an existing change |
| `/review-change` | Reviewing an existing diff |
| `/release-check` | Final pre-PR/pre-merge checklist |
| `/context-handoff` | Save compact context before the session gets too long |
| `/resume-work` | Continue from the latest saved run |

### Project instructions

| File | Purpose |
| --- | --- |
| `AGENTS.md` | Shared rules for AI coding tools |
| `CLAUDE.md` | Claude Code entrypoint that imports `AGENTS.md` |
| `.claude/settings.json` | Permission defaults and safety controls |
| `.claude/rules/` | Security, testing, git, documentation, and coding rules |

### Run artifacts

Every task gets a folder like:

```text
.agent-runs/2026-06-17-add-password-reset-flow/
```

Inside it:

```text
intent.md
plan.md
test-plan.md
implementation-log.md
test-report.md
review-report.md
merge-checklist.md
status.md
handoff.md
```

The two most important resume files are:

| File | Purpose |
| --- | --- |
| `status.md` | Tracks the current phase and completed phases |
| `handoff.md` | Compact summary for a fresh Claude Code session |

---

## Quick install (one line)

Run the command for your shell from inside the project you want to add the kit to.

**macOS / Linux (and Windows Git Bash or WSL):**

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash
```

**Windows PowerShell:**

```powershell
irm https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.ps1 | iex
```

Both clone the kit into a temporary directory and copy its files into the current project. Existing files are backed up, not overwritten.

> **Windows note:** the kit's workflow runs `bash` scripts at runtime (the Stop hook runs `bash scripts/checkpoint.sh`, and `/ship` calls `scripts/create-run.sh`), so you need **Git Bash** or **WSL** installed to *run* the workflow. The PowerShell installer only places the files.

Then open Claude Code in your project and run `/ship Your task here`.

## Install into an existing project

From this repository folder, run:

```bash
./scripts/install.sh /path/to/your-project
```

Or copy the files manually:

```bash
cp -R .claude AGENTS.md CLAUDE.md templates scripts /path/to/your-project/
cd /path/to/your-project
chmod +x scripts/*.sh
```

Then open Claude Code inside your project:

```bash
claude
```

Start a change:

```text
/model opusplan
/ship Add password reset flow
```

For a smaller planning-only task:

```text
/plan-change Fix the checkout validation bug
```

---

## How to use the workflow

### 1. Start with `/ship`

Example:

```text
/ship Add password reset flow
```

Claude should create a run folder and write the first artifacts.

### 2. Planner creates `plan.md`

The planner inspects the codebase and creates a plan.

It should not edit source files.

### 3. Test architect creates `test-plan.md`

The test architect decides what needs to be tested before the coder writes code.

This prevents the coder from inventing weak tests after the fact.

### 4. You approve the plan

Claude should summarize:

- Goal
- Plan
- Tests
- Risks
- Files likely to change

Then it should wait for your approval before implementation.

### 5. Coder implements the approved plan

The coder should use the approved plan and test plan only.

If the plan is wrong, the coder should stop and update the plan instead of silently changing scope.

### 6. Tester runs checks

The tester runs the commands from `test-plan.md` and project quality gates.

It must not say tests passed unless they actually ran and passed.

### 7. Reviewer reviews the final diff

The reviewer compares the implementation against:

- Your request
- `plan.md`
- `test-plan.md`
- `implementation-log.md`
- `test-report.md`
- `git diff`
- Security and project rules

The reviewer returns one of:

```text
APPROVE
REQUEST CHANGES
BLOCK
```

### 8. Human merges

The kit is designed to prepare a merge-ready PR, not to merge automatically.

Humans and CI decide when to merge.

---

## Resume and context handoff

Long Claude Code sessions can run out of context. This kit saves progress so you can start a new session without rereading the entire project.

### Before context gets too large

Run:

```text
/context-handoff
```

This updates:

```text
.agent-runs/<run-id>/status.md
.agent-runs/<run-id>/handoff.md
```

Then start a new Claude Code session and say:

```text
/resume-work
```

or simply:

```text
continue
```

### What happens when you say `continue`

Claude should:

1. Read `.agent-runs/latest-run.txt`.
2. Read the active run's `status.md`.
3. Read the active run's `handoff.md`.
4. Tell you what is already done.
5. Continue from the next unchecked phase.

Examples:

```text
continue
```

```text
continue with plan
```

```text
go to phase 2
```

If Phase 1 is already done and you say `continue with plan`, Claude should say planning is already complete and move to the next phase instead of doing the plan again.

---

## Repository layout

```text
agentic-ship-kit/
├── .claude/
│   ├── agents/
│   ├── rules/
│   ├── settings.json
│   └── skills/
├── .github/
│   └── workflows/
├── examples/
├── scripts/
├── templates/
├── tests/
├── AGENTS.md
├── CLAUDE.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

---

## Customization guide

After installing into a real project, update these first:

| Area | File |
| --- | --- |
| Project commands | `AGENTS.md` |
| Claude-specific behavior | `CLAUDE.md` |
| Security rules | `.claude/rules/security.md` |
| Test rules | `.claude/rules/testing.md` |
| Branch rules | `.claude/rules/git-workflow.md` |
| Permission controls | `.claude/settings.json` |
| Workflow details | `.claude/skills/ship/SKILL.md` |

For example, replace generic commands like:

```bash
npm test
```

with your real commands:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm test:e2e
```

### Adding custom agents, skills, and rules

See [docs/extending.md](docs/extending.md) for a full guide on:
- Adding a project-specific agent (e.g. a dependency auditor)
- Adding a custom skill (e.g. `/security-scan`)
- Adding a project-specific rule (e.g. a rate-limiting rule)
- Replacing a built-in agent with your own version

### Rollback planning

For changes that touch data models, migrations, or payments, fill out `templates/rollback.md` and include it in `plan.md`. The template prompts for reversibility, exact rollback steps, data impact, estimated time, and verification checks.

---

## Update

To pull the latest kit files into an existing project:

```bash
curl -fsSL https://raw.githubusercontent.com/briankiprop/agentic-ship-kit/main/scripts/bootstrap.sh | bash -s -- --update
```

This updates `.claude/`, `templates/`, and `scripts/` and backs up existing files. `AGENTS.md` and `CLAUDE.md` are left untouched (they are yours to customise). Add `--force` to also overwrite them.

## Uninstall

```bash
bash scripts/uninstall.sh
```

Moves `.claude/`, `templates/`, and `scripts/` to a timestamped backup folder. Pass `--delete` to remove them permanently, or `--all` to also remove `AGENTS.md` and `CLAUDE.md`.

---

## Team collaboration

The kit is designed for a single engineer running it in their Claude Code session. For teams:

- **Commit `.claude/`, `scripts/`, `templates/`, `AGENTS.md`, and `CLAUDE.md`** so every team member gets the same workflow on a fresh clone.
- **Do not commit `.agent-runs/`** — each engineer's run folders are local artifacts (already in `.gitignore`).
- **One engineer owns a run** — two people should not drive the same `.agent-runs/<run-id>/` folder at the same time.
- **Branch per run** — the coder agent creates a feature branch, so concurrent work naturally separates into separate PRs.
- If your team uses a shared `.claude/settings.json`, keep permission overrides in `.claude/settings.local.json` (gitignored) instead so personal settings don't overwrite shared ones.

---

## CI/CD integration

The kit ships a GitHub Actions workflow (`.github/workflows/ci.yml`) that validates kit structure. To run the kit's quality gates in CI, call `scripts/run-quality-gates.sh` from your own workflow:

```yaml
- name: Run quality gates
  run: bash scripts/run-quality-gates.sh
```

`run-quality-gates.sh` auto-detects Node, Python, and Rails projects and runs the appropriate checks. Customise it for your project's commands.

The kit does **not** auto-trigger `/ship` from CI — that is an interactive, human-approved workflow. CI should run linting, tests, and audits independently.

---

## Troubleshooting

### `checkpoint.sh` fails silently

The Stop hook always exits 0 so it never breaks your turn. If you suspect it is not running, check `.agent-runs/latest-run.txt` exists and points to a valid folder. Run it manually to see any errors:

```bash
bash scripts/checkpoint.sh
```

### Python not found on Windows

On Windows Git Bash, `python3` may be the Microsoft Store stub. The scripts try `python3` then `python` automatically. If both fail, install Python from [python.org](https://www.python.org) and add it to your PATH.

### `latest-run.txt` points to a missing folder

Delete or update the file manually:

```bash
echo ".agent-runs/2026-06-18-my-task" > .agent-runs/latest-run.txt
```

Or let the next `/ship` create a fresh run.

### Reviewer returns REQUEST CHANGES — what now?

See the [phase recovery](#phase-recovery) section below.

### Agent created files on `main` instead of a branch

The `check-branch.sh` script warns about this. Create a branch and move the commits:

```bash
git checkout -b agent/my-task
git branch -f main HEAD~<n>   # move main back n commits
```

### `.gitignore` block was not added

Run install manually:

```bash
bash scripts/install.sh "$PWD"
```

---

## Phase recovery

If an agent fails partway through, or the reviewer asks for changes, use these recovery steps:

| Situation | What to do |
| --- | --- |
| Reviewer returns `REQUEST CHANGES` | Re-invoke the `coder` agent with the reviewer's feedback. Do not re-run the full pipeline. |
| Reviewer returns `BLOCK` | Fix the blocking issue, then re-invoke `verify`. Do not merge until `verify` returns `APPROVE`. |
| Coder crashed mid-implementation | Check `implementation-log.md` for what was done, then say `continue` to resume from that point. |
| Tests failed after coder ran | Fix the failing tests or the code, then re-invoke `tester` only (not the full pipeline). |
| Plan became wrong during implementation | Stop the coder, update `plan.md`, get re-approval, then resume coder. |
| Need to redo a single phase | State the phase explicitly, e.g. `re-run phase 5 testing` — Claude will run that agent only. |

To revert a completed phase and redo it, update `status.md` to uncheck the relevant phase box and set `phase:` to the phase before it. Then say `continue`.

---

## Safety model

This kit is built around five rules:

1. Plan before editing.
2. Design tests before coding.
3. Let only the coder edit source files.
4. Keep `status.md` and `handoff.md` accurate.
5. Let humans and CI decide merge readiness.

Do not let an agent bypass the plan, skip failed tests, or merge directly to `main`.
