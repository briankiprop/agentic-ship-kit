---
name: ship-skit
description: End-to-end workflow for planning, building, testing, and reviewing a code change. Works globally without any per-project files. Triages the request and scales process to risk.
argument-hint: "[what you want to build or fix]"
disable-model-invocation: true
---

# Ship-Skit Workflow

Use this skill to build or fix anything in your project. Just describe what you want:

```
/ship-skit add a login page with email and password
/ship-skit fix the bug where prices show as zero
/ship-skit refactor the user service to use async/await
```

This skill works in **any project** — it does not require the kit to be installed per-project. It creates a `.agent-runs/` folder in your project to track progress. Nothing else is added to your project.

If the project also has a per-project `/ship` skill installed, that one controls project-specific rules. This global skill picks them up automatically.

---

## Before starting

If you said "continue", "resume", or "go to phase 2" — do not start over. Read `.agent-runs/latest-run.txt`, then that run's `status.md` and `handoff.md`, then continue from the next unchecked phase.

If context is close to the limit, save progress first:
- Update `status.md` and `handoff.md` with current phase and next step
- Tell the user to start a new session and say `continue`

---

## Step 0: Triage

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

### Triage examples

| What you ask for | Tier | Why |
| --- | --- | --- |
| Fix typo in README | Trivial | Docs only |
| Add a null check in formatDate | Small | One file, no Rule 1 |
| Fix misaligned button | Small | CSS only |
| Add login with Google | Large | Rule 1 — auth |
| Add `deleted_at` column | Large | Rule 1 — database migration |
| Fix bug in session expiry | Large | Rule 1 — sessions |
| Refactor the whole API layer | Large | Cross-cutting, unclear scope |

---

## Step 1: Create the run folder

Create a folder to track this work. Run these bash commands:

```bash
SLUG="$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | head -c 40 | sed 's/-$//')"
RUN_ID="$(date +%Y-%m-%d)-$SLUG"
mkdir -p ".agent-runs/$RUN_ID"
echo ".agent-runs/$RUN_ID" > .agent-runs/latest-run.txt
```

Then create these files inside the run folder (use the templates below):
- `intent.md` — what the user asked for
- `plan.md` — the implementation plan (filled by design agent)
- `test-plan.md` — what to test (filled by design agent)
- `implementation-log.md` — what was changed (filled by coder agent)
- `test-report.md` — test results (filled by verify agent)
- `review-report.md` — review decision (filled by verify agent)
- `merge-checklist.md` — pre-PR checklist
- `status.md` — current phase tracker
- `handoff.md` — compact summary for session resume

**If the project has `scripts/create-run.sh`**, use it instead:
```bash
bash scripts/create-run.sh "Your task description"
```

---

## Step 2: Write intent.md

Write what the user asked for, any constraints you noticed, and what success looks like. Keep it short — one paragraph is enough.

Update `status.md` to show Phase 0 (intake) is complete.

---

## Tier: Trivial

Make the change inline. No agents. No run folder needed (skip Step 1). Run only the most relevant check (e.g. a markdown lint if you changed docs). Work on a branch, never on main.

---

## Tier: Small

1. Do Steps 1–2 above.
2. Invoke the `builder` agent. It will: make a short plan, implement the change on a branch, add a test, and write `implementation-log.md` and `test-report.md`.
3. If everything looks clean, run `/release-check` and prepare the PR.
4. Never merge to main.

---

## Tier: Large — Full pipeline

```
Your request → design → You approve → coder → verify → release check → You merge
```

### Step 3: Design (plan + tests)

Invoke the `design` agent. It will:
- Read the relevant parts of your codebase
- Write `plan.md` with the implementation approach
- Write `test-plan.md` with what needs to be tested
- NOT touch any source files

Update `status.md` to Phase 1 (plan) complete.

**Project rules:** If `AGENTS.md` exists in the project, the design agent reads it for quality gates and security rules. If not, it uses the built-in rules from `~/.claude/rules/`.

### Step 4: You approve the plan

Show the user:
- What will be built (goal)
- The plan summary
- What will be tested
- The biggest risks
- Which files will likely change

**Wait for the user to say yes before any code is written.**

After approval, update `status.md` to Phase 3 (approval) complete.

### Step 5: Coder implements

Invoke the `coder` agent. It will:
- Create a feature branch (never work on main)
- Implement exactly what was approved
- Add or update tests
- Write `implementation-log.md`
- Keep `status.md` and `handoff.md` up to date

If the plan turns out to be wrong during implementation, the coder stops, updates `plan.md`, and waits for re-approval. It does not silently change scope.

### Step 6: Verify (tests + review)

Invoke the `verify` agent. It will:
- Run the test commands from `test-plan.md`
- Run quality gates (lint, typecheck, audit) — auto-detected for Node, Python, Rails
- Review the diff against the plan and test plan
- Write `test-report.md` and `review-report.md`
- Return one of: **APPROVE**, **REQUEST CHANGES**, or **BLOCK**

### Step 7: Release check

Use `/release-check` before opening a PR. Never merge directly to main.

---

## Phase recovery — when things go wrong

| What happened | What to do |
| --- | --- |
| Reviewer said REQUEST CHANGES | Give the feedback to the `coder` agent. Do not redo planning. |
| Reviewer said BLOCK | Fix the blocking issue, then re-run `verify`. |
| Coder stopped halfway | Say `continue` — it reads `implementation-log.md` and picks up where it left off. |
| Tests failed | Fix the code or tests, then re-run `verify` only. |
| Plan was wrong | Stop, update `plan.md`, get re-approval, then resume `coder`. |
| Need to redo a phase | Uncheck that phase in `status.md` and say which phase to redo. |

---

## Saving your progress (session handoff)

Before the context gets too large, save progress so you can continue in a new session:

1. Update `status.md` with the current phase
2. Update `handoff.md` with: what's done, what's next, key decisions, any risks (aim for 200–400 words)
3. Tell the user: "Start a new Claude Code session and say `continue`"

In the new session, Claude reads `.agent-runs/latest-run.txt` → `status.md` → `handoff.md` and picks up from the next unchecked phase.

**Note:** The automatic checkpoint (Stop hook) only runs if `scripts/checkpoint.sh` exists in the project. If you installed the kit globally only, save progress manually using the steps above before ending a long session.

---

## Artifact templates

Use these when creating the run folder files in Step 1.

### status.md
```markdown
---
run_id: PLACEHOLDER
phase: 0-intake
last_completed_phase: none
next_action: Write intent.md, then invoke design agent.
updated_by: ship-skit
last_checkpoint: never
---

## Phase tracker

- [ ] Phase 0: Intent captured
- [ ] Phase 1: Plan created
- [ ] Phase 2: Test plan created
- [ ] Phase 3: Human approved
- [ ] Phase 4: Coder implemented
- [ ] Phase 5: Tests passed
- [ ] Phase 6: Review approved
- [ ] Phase 7: Release check done
```

### handoff.md
```markdown
---
run_id: PLACEHOLDER
last_updated: PLACEHOLDER
current_phase: 0-intake
next_action: Write intent.md, then invoke design agent.
---

## Summary

(Fill this in before ending a long session.)

## Decisions

## Next step

Say `continue` in a new Claude Code session.
```

### merge-checklist.md
```markdown
# Merge Checklist

- [ ] All tests pass
- [ ] Reviewer returned APPROVE (not REQUEST CHANGES or BLOCK)
- [ ] No secrets or credentials in the diff
- [ ] PR title and description written
- [ ] Branch is not main or master
- [ ] CI is green (if configured)
```
