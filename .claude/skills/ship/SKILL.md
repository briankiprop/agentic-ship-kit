---
name: ship
description: End-to-end workflow for planning, testing, implementing, verifying, reviewing, and handing off a code change before PR. Triages the request and routes to a fast path for small work or the full pipeline for risky work.
argument-hint: "[feature, bug fix, refactor, or task]"
disable-model-invocation: true
---

# Ship workflow

Use this workflow for any meaningful code change. It scales the amount of process to the risk and size of the change, so a typo does not pay for the full pipeline.

## Before starting

If the user says "continue", "resume", "continue with plan", "go to phase 2", or similar, do not start over. Use `/resume-work` first.

If context is getting close to red, use `/context-handoff` before continuing.

## Step 0: Triage

Classify the request into a tier. Apply rules top to bottom; first match wins.

1. **Risk override → `large`, unconditionally.** Route to `large` regardless of size if the request or the files it will likely touch involve any of:
   - auth, login, session, token, password, OAuth, SSO, permissions, roles
   - payments, billing, checkout, refunds, pricing logic
   - data models, schema, migrations, DB columns, indexes, ORM models
   - security primitives: crypto, secrets handling, trust-boundary input validation, file upload, deserialization, SSRF, open redirect
   - deleting or rewriting existing tests

   If you are unsure whether a keyword applies, treat it as matched.
2. **`trivial`** — a single concern with no runtime behavior change: typo, comment, doc/markdown, formatting, copy. Roughly ten or fewer changed lines in non-executable context.
3. **`small`** — localized to one file (or one file plus its test), bounded blast radius, clear acceptance criteria, and no rule-1 keyword.
4. **`large`** — everything else, and the default whenever scope is ambiguous.

State the decision and the matched rule, e.g. `Tier: large (rule 1 — touches auth)`. The user may override **upward** (to a stricter tier); never silently downgrade a rule-1 match. **If in doubt, escalate a tier.**

### Triage examples

| Request | Tier | Reason |
| --- | --- | --- |
| Fix typo in README | trivial | docs only, zero runtime change |
| Reformat payment.ts to match style guide | trivial | formatting only — but note: if the file touches payments logic and reformatting changes behavior, escalate |
| Add null check in formatDate helper | small | one function, no rule-1 keyword |
| Fix misaligned button on mobile | small | CSS/UI only, bounded blast radius |
| Fix bug in session expiry check | large | rule 1 — touches session |
| Add `display_name` column to users | large | rule 1 — data model change |
| Add logging to payment webhook | large | rule 1 — payments |
| Switch from bcrypt to argon2 | large | rule 1 — security primitive |
| Refactor API response formatting | large | cross-cutting, scope ambiguous → escalate |

## Step 0b: Route

Use the matched row to decide which agents and sections to use.

| Trigger | Tier | Agents to invoke | Skip | Forced sections |
| --- | --- | --- | --- | --- |
| typo / formatting | trivial | none (do it inline) | all subagents | none |
| docs-only / markdown | trivial | none (do it inline) | test design, review | none |
| localized bug (no rule-1) | small | `builder`, then light `verify` | separate planner/test-architect; full reviewer if self-test clean | lite plan, implementation-log, test-report |
| single-file feature (no rule-1) | small | `builder`, then `verify` (sonnet) | separate test design | as above |
| auth / session | large | `design` → approval → `coder` → `verify` (force security pass) | nothing | non-empty `## Security review` + regression test |
| payments / billing | large | full 3-agent + security pass | nothing | security review + rollback note |
| data model / migration | large | full 3-agent | nothing | `## Data and migration` + a `## Rollback` section in plan and merge-checklist |
| security primitive | large | full 3-agent + security pass | nothing | security review + threat note |
| refactor / cross-cutting | large | full 3-agent | nothing | standard |

State which standard steps you are skipping and why. Ensure any forced sections exist before the approval gate.

## Tier: trivial

Make the change inline in this session. **Do not spawn subagents.** Create at most one artifact (`intent.md`, or none if the user opts out). Run only the relevant check (markdown lint, or the structure test if a kit file changed). Still work on a feature branch. Never merge to main or master.

## Tier: small

1. Create the run folder (Step 1 below). Write a short `intent.md`.
2. Invoke the `builder` subagent (sonnet, worktree). It writes a lite `plan.md`, implements on a branch, adds/updates the test, self-tests, and writes `implementation-log.md` and `test-report.md`.
3. Approval gate is optional for small changes; ask the user if the change is borderline.
4. Run a light `verify` pass (or go straight to `/release-check` if the self-test is clean and no rule-1 keyword applies).
5. Never merge to main or master.

## Tier: large — collapsed pipeline

The large tier uses three agents instead of five, with the human approval gate unchanged:

```text
Request → design → Human Approval → coder → verify → Release Check → Human Merge
```

- `design` (opus) merges the **planner** and **test-architect** roles: it produces `plan.md` and `test-plan.md` without editing source files.
- `coder` (sonnet, worktree) implements the approved plan.
- `verify` (opus) merges the **tester** and **reviewer** roles: it runs the tests and quality gates, reviews the diff, and decides APPROVE / REQUEST CHANGES / BLOCK.

### Roles reference (collapse mapping)

The original five roles still exist as standalone agents and may be invoked directly (via `/plan-change`, `/test-change`, `/review-change`) when you want them separate:

- `design` = `planner` + `test-architect`
- `coder` = unchanged
- `verify` = `tester` + `reviewer`

### Step 1: Create run folder

Create:

```text
.agent-runs/<date>-<short-slug>/
```

Add these artifacts:

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

Use this script when available:

```bash
scripts/create-run.sh "<task>"
```

The script also updates `.agent-runs/latest-run.txt`.

### Step 2: Capture intent

Write `intent.md` with the original request, assumptions, constraints, success criteria, and out-of-scope items. Update `status.md` to show Phase 0 complete.

### Step 3: Design (plan + test plan)

Invoke the `design` subagent. It inspects only the relevant codebase, produces `plan.md` (with the `AGENTIC_SHIP_PHASE` comment and a `Current status` section) and `test-plan.md`. No source files change during this step. Update `status.md`.

### Step 4: Approval gate

Show the user the goal, plan summary, test summary, risks, files likely to change, and current/next phase. Ask for approval before implementation. Do not code before approval. After approval, update `status.md`.

### Step 5: Implementation

After approval, invoke the `coder` subagent. It creates or uses a feature branch, implements the approved plan, adds or updates tests, updates `implementation-log.md`, and keeps `status.md` and `handoff.md` accurate enough to resume.

### Step 6: Verify (test + review)

Invoke the `verify` subagent. It runs the required commands and produces `test-report.md` (PASS only if checks actually passed), reviews the diff against the plan and test plan, produces `review-report.md`, decides APPROVE / REQUEST CHANGES / BLOCK, and updates `status.md`.

### Step 7: Release check

Use `/release-check` before opening or merging a PR. Never merge directly to main or master.

## Context handoff rule

Before the context indicator turns red, or before ending the session, use `/context-handoff`. The Stop hook keeps `status.md` and `handoff.md` timestamped, but you must write the narrative handoff yourself.

The handoff must let a new session continue with:

```text
/resume-work
```

or:

```text
continue
```

## Final response

Summarize: the tier and why, what changed, current phase, completed phases, test status, review decision (for small/large), remaining risks, a suggested PR title and description, and the exact next command or prompt.
