---
name: test-change
description: Run the testing workflow for an existing implemented change and produce a test report.
argument-hint: "[optional scope or run folder]"
disable-model-invocation: true
---

# Test-only workflow

Use this when implementation is already complete and the user wants verification.

1. Identify the current run folder from the argument, `.agent-runs/latest-run.txt`, or newest `.agent-runs/` folder.
2. Read `status.md` and `handoff.md` first.
3. Read `.agent-runs/<run-id>/test-plan.md` if available.
4. Read `AGENTS.md` and `CLAUDE.md` for required checks.
5. Invoke the `tester` subagent.
6. Produce `.agent-runs/<run-id>/test-report.md`.
7. Update `status.md` and `handoff.md`.
8. Mark PASS only when required checks actually passed.

Do not edit source files.

## Agent execution rules

- If `.ship-context/INDEX.md` exists, read it before exploring the codebase.
- Read only files relevant to the stated change — not the whole project.
- Dispatch independent read operations in parallel (multiple Read calls in one message).
- Never re-read files already covered in the run's existing `test-plan.md` or `handoff.md`.
