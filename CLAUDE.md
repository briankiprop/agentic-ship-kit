@AGENTS.md

# Claude Code Instructions

Use the agentic shipping workflow for all non-trivial changes.

For feature work, bug fixes, refactors, migrations, auth changes, payment changes, data model changes, or security-sensitive work:

1. Start with `/ship`.
2. Use the planner before editing files.
3. Create a test plan before implementation.
4. Do not edit source files until the plan is approved.
5. Implement on a feature branch, never directly on `main` or `master`.
6. Run the required quality gates before review.
7. Produce a review report before PR or merge.
8. Never merge automatically.

`/ship` triages every request into a tier so process scales with risk:

- **trivial** (typo, docs, formatting): handle inline, no subagents, run only the relevant check.
- **small** (localized bug fix or single-file feature, no risk keywords): one `builder` agent plus a light `verify`.
- **large** (features, refactors, migrations, or anything touching auth, payments, data models, or security): the full pipeline, collapsed to `design` → approval → `coder` → `verify`.

Anything touching auth, payments, data models, migrations, or security always routes to **large**. When in doubt, escalate a tier.

## Claude-specific conventions

- Prefer subagents over a single long conversation for substantial work.
- Keep artifacts in `.agent-runs/<date>-<slug>/`.
- Keep `.agent-runs/latest-run.txt` pointed at the active run.
- Keep `status.md` and `handoff.md` current.
- If a plan becomes incorrect during implementation, stop and update the plan before continuing.
- Do not skip the tester or reviewer role for security-sensitive work.
- Never claim tests passed unless the command actually ran and passed.

## Resume behavior

When the user says "continue", "continue with plan", "resume", "go to phase 2", or similar:

1. Use `/resume-work` behavior.
2. Read `.agent-runs/latest-run.txt`.
3. Read that run's `status.md`, `handoff.md`, and `intent.md`.
4. Tell the user what is already complete.
5. Continue from the next unchecked phase.
6. Do not reread the whole project unless the next phase requires it.

## Context handoff behavior

Before the context indicator becomes red, before `/clear`, or before ending a long session:

1. Use `/context-handoff` behavior.
2. Update `status.md`.
3. Update `handoff.md` with a compact summary, decisions, files, commands, risks, and next action.
4. Tell the user to start a new Claude Code session and run `/resume-work` or say `continue`.

## Proactive handoff rule

Do not wait to be asked to hand off. You MUST proactively run `/context-handoff` when the conversation is long:

- after each large agent turn,
- as the context indicator approaches yellow or red,
- before any `/clear`,
- and before spawning the final agent in a long run.

A Stop hook (`scripts/checkpoint.sh`) keeps `status.md` and `handoff.md` timestamped and mirrors the current phase after every turn, so resume state survives an abrupt context loss. But the hook only stamps metadata — it does NOT write the narrative handoff. You must write that yourself via `/context-handoff`.
