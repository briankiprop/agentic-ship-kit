# AGENTS.md

Shared instructions for AI coding agents working in this repository.

## Project principles

- Prefer small, reviewable changes.
- Never push directly to `main` or `master`.
- Never merge without CI passing.
- Never hide failing tests.
- Never remove tests to make a change pass.
- Never commit secrets, tokens, private keys, `.env` files, or credentials.
- Keep implementation aligned with the approved plan.
- If the plan becomes wrong, stop and update the plan before continuing.
- Keep run artifacts updated so another session can resume without rereading the whole project.

## Required workflow

For every meaningful code change:

1. Create an intent document.
2. Create an implementation plan.
3. Create a test plan.
4. Get approval.
5. Implement on a branch.
6. Add or update tests.
7. Run quality gates.
8. Produce a test report.
9. Produce a review report.
10. Run the release checklist.
11. Open a PR.

## Run artifacts

Each change should have a run folder:

```text
.agent-runs/<date>-<slug>/
```

Required files:

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

`.agent-runs/latest-run.txt` should contain the active run folder path.

## Phase names

Use these phases consistently:

```text
0-intake
1-plan
2-test-design
3-approval
4-implementation
5-testing
6-review
7-release-check
human-merge
```

When the user says "continue", "continue with plan", "resume", or "go to phase 2", read `status.md` and `handoff.md` first. Continue from the next unchecked phase. Do not repeat completed phases unless the user asks for a revision.

## Context handoff

Hand off proactively — do not wait to be asked. Before the context indicator becomes red, after a large agent turn, before `/clear`, or before ending a long session:

1. Update `status.md`.
2. Update `handoff.md`.
3. Tell the user the exact next prompt to use in a new session.

A Stop hook (`scripts/checkpoint.sh`) timestamps `status.md` and `handoff.md` after every turn so resume state survives an abrupt context loss, but it does not write the narrative handoff — you must.

The next session should be able to resume with:

```text
/resume-work
```

or:

```text
continue
```

### handoff.md structure

Keep `handoff.md` under 150 lines (~400 words). Required sections:

```markdown
## Summary
One paragraph. Task, current phase, what's done.

## Changed files
- path/to/file.ext — what changed and why (one line each)

## Key decisions
- Decision and why

## Next action
Exact next step for the resuming session.

## Commands run
Last 3–5 commands with outcomes.

## Unknowns and gaps
- [ ] Things not verified, not tested, or uncertain — explicit blind spots.
```

Omit anything the next session can derive from `status.md` or `git diff`. Never paste full diffs or file contents.

## Codebase context cache

`scripts/build-context.sh` generates `.ship-context/` — four markdown files (~800–1500 tokens total) summarising the repo for agents:

- `INDEX.md` — repo overview, languages, entry points
- `structure.md` — file tree with per-file descriptions
- `symbols.md` — functions, classes, exports (grep-based, no LLM)
- `recent-changes.md` — last 20 commits and diff stats

**Agents must read `.ship-context/INDEX.md` first** before any Grep or Glob sweep. Only open individual source files when the task specifically requires their full content.

The cache is rebuilt automatically by the `post-commit` hook when code files change. Force a rebuild: `bash scripts/build-context.sh --force`.

## Branch naming

Use one of:

```text
agent/<short-feature-name>
fix/<short-bug-name>
chore/<short-task-name>
```

## Standard quality gates

Run the relevant commands for this project. For Node projects:

```bash
npm run lint
npm run typecheck
npm test
npm run test:e2e
npm audit
```

For Python projects:

```bash
python -m compileall .
python -m pytest
python -m pip-audit
```

For this template repository:

```bash
python3 tests/test_template_structure.py
```

## Security rules

- Validate all user input.
- Enforce authorization server-side.
- Do not trust client-side checks.
- Do not log secrets, tokens, passwords, session cookies, reset tokens, or personal data.
- Use parameterized database queries.
- Prefer allowlists over blocklists.
- Add regression tests for security-sensitive fixes.
- Check dependency risk when adding new packages.
- Avoid adding dependencies unless the plan justifies them.

## Review rules

A change is not ready if:

- It does not match the approved plan.
- It lacks tests for new behavior.
- It has failing checks.
- It changes unrelated files.
- It introduces secrets or unsafe logging.
- It weakens auth, validation, or error handling.
- It creates unclear migrations or rollback risks.
- It skips documentation for behavior that users or operators need to know.
- It leaves `status.md` or `handoff.md` misleading or stale.

## Phase recovery

When something goes wrong mid-run, recover at the phase level — do not restart the whole pipeline.

| Situation | Recovery action |
| --- | --- |
| Reviewer returns `REQUEST CHANGES` | Re-invoke `coder` with reviewer feedback. Do not re-run design or tester unless needed. |
| Reviewer returns `BLOCK` | Fix the blocking issue, re-invoke `verify`. Do not open a PR until `verify` returns `APPROVE`. |
| Coder crashed mid-implementation | Read `implementation-log.md`, then say `continue` — resume from where it stopped. |
| Tests fail after coder ran | Fix code or tests, then re-invoke `tester` only. |
| Plan became wrong during coding | Stop. Update `plan.md`. Get re-approval. Resume `coder`. |
| Need to redo a specific phase | Uncheck that phase in `status.md`, set `phase:` to the preceding phase, then say `continue`. |

Never re-run completed phases silently. Always tell the user which phase is being redone and why.

## Triage examples

Use these as calibration when classifying a request.

**Trivial** (no subagents, inline fix):
- "Fix typo in the README"
- "Update the copyright year in the header comment"
- "Reformat this function to match the style guide"

**Small** (`builder` + light `verify`):
- "The login button is misaligned on mobile" (CSS/UI only, no auth logic)
- "Add a missing null check in the formatDate helper"
- "Write a unit test for the parseAmount function"

**Large** (full pipeline):
- "Add password reset via email" → auth + data model
- "Switch from bcrypt to argon2" → security primitive
- "Add a `deleted_at` column for soft deletes" → migration
- "Refactor the payment service to support multiple currencies" → payments
- "Move user preferences to a new table" → data model + migration

**Borderline — escalate to large**:
- "Fix a bug in the session expiry check" → touches session/auth → large
- "Add logging to the payment webhook handler" → touches payments → large
- "Update the user model to add a `display_name` field" → data model → large
