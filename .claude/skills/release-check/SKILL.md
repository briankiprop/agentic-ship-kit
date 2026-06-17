---
name: release-check
description: Final pre-merge/release checklist for a branch after implementation, testing, review, and handoff.
argument-hint: "[optional release or PR name]"
disable-model-invocation: true
---

# Release check workflow

Use this immediately before opening or merging a PR.

First read:

- `.agent-runs/latest-run.txt`
- `.agent-runs/<run-id>/status.md`
- `.agent-runs/<run-id>/handoff.md`
- `.agent-runs/<run-id>/merge-checklist.md`

Required checks:

- Branch is not `main` or `master`.
- Plan exists.
- Test plan exists.
- Implementation log exists.
- Test report exists.
- Review report exists.
- Reviewer decision is APPROVE.
- Required quality gates passed.
- CI is passing.
- No secrets are present in diff.
- No unrelated files are changed.
- Rollback/migration notes exist when relevant.
- `status.md` and `handoff.md` accurately describe the final state.

Output:

- Merge checklist status
- PR title
- PR description
- Known risks
- Final recommendation

Never merge automatically.
