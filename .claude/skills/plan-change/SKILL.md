---
name: plan-change
description: Create only an implementation plan for a requested change without editing source files.
argument-hint: "[change request]"
disable-model-invocation: true
---

# Plan-only workflow

Use this when the user wants a plan but not implementation.

If the user says "continue" or "continue with plan", use `/resume-work` first and do not start over.

1. Create or identify the current run folder.
2. Capture the user request in `intent.md`.
3. Inspect relevant project files.
4. Invoke the `planner` subagent.
5. Write or update `.agent-runs/<run-id>/plan.md`.
6. Update `.agent-runs/<run-id>/status.md`.
7. Update `.agent-runs/<run-id>/handoff.md` with the next action.
8. End with assumptions, risks, acceptance criteria, and next phase.

Do not edit source files.
