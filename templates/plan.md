# Plan

<!-- AGENTIC_SHIP_PHASE v1
run_id: TODO
phase: 1-plan
last_completed_phase: 0-intake
next_phase: 2-test-design
next_action: Complete this plan, then invoke test-architect.
updated_by: planner
-->

## Current status

- Current phase: 1-plan
- Last completed phase: 0-intake
- Next phase: 2-test-design
- Next action: Complete this plan, then create `test-plan.md`.

## Phase tracker

- [x] Phase 0: Intent captured / run folder created
- [ ] Phase 1: Planner created this `plan.md`
- [ ] Phase 2: Test architect created `test-plan.md`
- [ ] Phase 3: Human approved implementation
- [ ] Phase 4: Coder implemented approved plan
- [ ] Phase 5: Tester produced `test-report.md`
- [ ] Phase 6: Reviewer produced `review-report.md`
- [ ] Phase 7: Release checklist / PR preparation complete

## Goal

## Non-goals

## Current codebase findings

## Proposed changes

## Files likely to change

## Security considerations

<!-- Required for auth, payments, session, crypto, file upload, or trust-boundary changes.
     Must be non-empty before the approval gate for large-tier changes.

     Minimum content:
     - What trust boundaries are crossed?
     - What inputs are validated and how?
     - What authorization checks are in place?
     - Are there any new secrets, tokens, or credentials? How are they stored?
     - Are there regression tests for the security-sensitive paths?

     Example:
     - Password reset tokens are single-use, expire in 1 hour, stored hashed.
     - Token lookup uses a constant-time comparison to prevent timing attacks.
     - Regression test: expired token returns 400, reused token returns 400.
-->

## Data and migration considerations

<!-- Required for schema changes, new columns, index changes, or ORM model changes.
     Must include a rollback section for large-tier changes.

     Minimum content:
     - What tables or models change?
     - Is the migration reversible? If not, why not?
     - What is the rollback plan?
     - Is there a backfill? How long will it take on production row counts?
     - Are there zero-downtime concerns (locking, index builds)?

     Example:
     - Add nullable `deleted_at` column to `users`. Reversible: drop column.
     - Backfill: not needed (NULL = not deleted).
     - No locking risk: nullable column addition is instant on Postgres 12+.
-->

## Rollback

<!-- Required for data model, migration, and payment changes.
     Describe exactly how to undo this change if it must be reverted after deploy.

     Example:
     - Run: rails db:rollback STEP=1
     - No data loss: the column is nullable and no rows were deleted.
     - Feature flag: set FEATURE_SOFT_DELETE=false to disable before rollback.
-->

## Testing implications

## Risks

## Acceptance criteria

- [ ] 

## Questions or assumptions

## Resume notes

Use this section to leave short notes for the next Claude Code session. Include the current decision, important files, and the exact next step.
