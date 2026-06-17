# Changelog

All notable changes to this project are documented here. This project follows [Semantic Versioning](https://semver.org/).

## Unreleased

## v0.1.0 - 2026-06-18

### Added

- Tiered `/ship` workflow: triage routes each request to a `trivial`, `small`, or `large` path so process scales with risk.
- Collapsed-role agents for the large tier: `design` (planner + test-architect), `coder`, and `verify` (tester + reviewer) — three agents instead of five.
- `builder` agent for the small tier: combined plan + implement + self-test in one pass.
- Stop-hook checkpointing (`scripts/checkpoint.sh`) that timestamps `status.md`/`handoff.md` after every turn so resume state survives abrupt context loss, plus a proactive-handoff rule.
- Context handoff and resume workflow (`/context-handoff`, `/resume-work`).
- `status.md` and `handoff.md` run artifacts.
- GitHub Actions CI workflow.
- Install script for copying the kit into existing projects.
- The five original agents (`planner`, `test-architect`, `coder`, `tester`, `reviewer`) remain available for direct invocation.
