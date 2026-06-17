---
name: resume-work
description: Resume the latest agentic run from status.md and handoff.md without rereading the whole project.
argument-hint: "[optional run folder]"
disable-model-invocation: true
---

# Resume workflow

Use this when a new Claude Code session starts, when the user says "continue", "continue with plan", "go to phase 2", "resume", or similar.

Goal: continue from the saved run state without wasting context.

## Step 1: Find the run folder

Prefer this order:

1. If the user gave a run folder, use it.
2. Else read `.agent-runs/latest-run.txt`.
3. Else choose the newest folder inside `.agent-runs/`.
4. If no run exists, say no run was found and suggest `scripts/create-run.sh "task"` or `/ship <task>`.

## Step 2: Read the resume files first

Read these files before doing anything else:

- `.agent-runs/<run-id>/status.md`
- `.agent-runs/<run-id>/handoff.md`
- `.agent-runs/<run-id>/intent.md`

Then read only the artifact needed for the next phase:

- Phase 1: `plan.md`
- Phase 2: `plan.md` and `test-plan.md`
- Phase 3: `plan.md` and `test-plan.md`
- Phase 4: `implementation-log.md`, plus relevant source files
- Phase 5: `test-plan.md` and `implementation-log.md`
- Phase 6: `review-report.md`, `test-report.md`, and `git diff`
- Phase 7: `merge-checklist.md`, `review-report.md`, and CI/status info

## Step 3: Interpret continuation phrases

When the user says:

- "continue" — continue to the next unchecked phase in `status.md`.
- "continue with plan" — if planning is complete, say it is already done and move to the next phase; otherwise finish `plan.md`.
- "go to phase 2" — check whether phase 1 is complete. If yes, start test design. If no, explain what is missing.
- "we already did that" — verify from `status.md`, `handoff.md`, and artifacts; then skip completed work.

Do not repeat completed phases unless the user explicitly asks to revise them.

## Step 4: Announce current state

Begin with a compact summary:

- Current run folder
- Completed phases
- Current phase
- Next action
- Anything blocked

## Step 5: Continue work

Continue using the normal `/ship` phase rules.

Before context gets too large again, run `/context-handoff`.
