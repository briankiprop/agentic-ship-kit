# Run Status

<!-- AGENTIC_SHIP_STATUS v1
run_id: TODO
phase: 0-intake
last_completed_phase: none
next_phase: 1-plan
next_action: Complete intent.md, then invoke planner.
updated_by: create-run
last_checkpoint: TODO
-->

## Current phase

0-intake

## Phase tracker

- [x] Phase 0: Intent captured / run folder created
- [ ] Phase 1: Planner created `plan.md`
- [ ] Phase 2: Test architect created `test-plan.md`
- [ ] Phase 3: Human approved implementation
- [ ] Phase 4: Coder implemented approved plan
- [ ] Phase 5: Tester produced `test-report.md`
- [ ] Phase 6: Reviewer produced `review-report.md`
- [ ] Phase 7: Release checklist / PR preparation complete

## Next action

Complete intent.md, then run the planner.

## Continue instructions for Claude

When the user says "continue", "continue with plan", "go to phase 2", or similar:

1. Read this file first.
2. Read `.agent-runs/latest-run.txt` if the run folder is unclear.
3. Read `handoff.md` for condensed context.
4. Read only the artifacts needed for the next unchecked phase.
5. Tell the user what is already done and what phase you are entering.
6. Do not repeat completed phases unless the user asks to revise them.

## Notes

-
