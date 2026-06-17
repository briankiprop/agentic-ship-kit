---
name: review-change
description: Review a completed diff against the plan, test report, security rules, and project standards.
argument-hint: "[optional run folder or branch]"
disable-model-invocation: true
---

# Review-only workflow

Use this when the user wants a final engineering review.

1. Identify the current run folder from the argument, `.agent-runs/latest-run.txt`, or newest `.agent-runs/` folder.
2. Read `status.md` and `handoff.md` first.
3. Read the plan, test plan, implementation log, and test report.
4. Inspect `git diff` and changed files.
5. Invoke the `reviewer` subagent.
6. Produce `.agent-runs/<run-id>/review-report.md`.
7. Update `status.md` and `handoff.md`.
8. Return one of: APPROVE, REQUEST CHANGES, BLOCK.

Do not edit source files.
Do not merge.
