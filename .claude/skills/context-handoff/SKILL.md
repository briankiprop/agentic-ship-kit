---
name: context-handoff
description: Create a compact handoff before context gets too large or before starting a new Claude Code session.
argument-hint: "[optional run folder or reason]"
disable-model-invocation: true
---

# Context handoff workflow

Use this when the context indicator is getting close to red, before `/clear`, before changing machines, or before ending a long session.

Goal: make the next Claude Code session able to continue without rereading the whole project.

## Step 1: Find the current run

Prefer this order:

1. If the user gave a run folder, use it.
2. Else read `.agent-runs/latest-run.txt`.
3. Else choose the newest folder inside `.agent-runs/`.
4. If none exists, ask the user whether to create one with `scripts/create-run.sh`.

## Step 2: Read only the essential files

Read:

- `.agent-runs/<run-id>/status.md`
- `.agent-runs/<run-id>/intent.md`
- `.agent-runs/<run-id>/plan.md`
- `.agent-runs/<run-id>/test-plan.md` if it exists
- `.agent-runs/<run-id>/implementation-log.md` if implementation started
- `.agent-runs/<run-id>/test-report.md` if testing started
- `.agent-runs/<run-id>/review-report.md` if review started
- `git status --short`
- `git diff --stat`

Do not reread the entire repository.

## Step 3: Update handoff.md

Write or update `.agent-runs/<run-id>/handoff.md` with:

- One-paragraph project summary
- Current task
- Current phase
- Completed phases
- Important decisions
- Files and areas involved
- Commands already run
- Test status
- Review status
- Open risks or blockers
- Exact next step
- Suggested user prompt for the new session

Keep it compact. Prefer useful facts over long explanations.

## Step 4: Update status.md

Update `.agent-runs/<run-id>/status.md` so the phase tracker and next action are accurate.

If the current phase is unclear, write `current phase unclear` and explain what needs to be checked first.

## Step 5: Final response

Tell the user:

- Handoff saved
- Current phase
- Exact next prompt to use in a new session

Recommended next prompt:

```text
/resume-work
```

or:

```text
continue
```
