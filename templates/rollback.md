# Rollback Plan

<!-- REQUIRED for any change that touches data models, migrations, payments, or
     other hard-to-reverse operations. Fill this out before the approval gate.
     Add a link to this file in plan.md and merge-checklist.md.

     If rollback is impossible, say so explicitly and describe the mitigation.
-->

## Is this change reversible?

<!-- Pick one and explain. -->

- [ ] **Yes** — fully reversible. Steps are below.
- [ ] **Partially** — some steps are irreversible. Describe which ones and why.
- [ ] **No** — cannot be undone. Mitigation:

## Rollback steps

<!-- Write the exact commands to undo this change after it is deployed.
     Be specific enough that someone who did not write the code can run these
     under pressure at 2am.

     Node / migration example:
       1. Run: npx sequelize-cli db:migrate:undo
       2. Deploy the previous application version (git revert + redeploy).
       3. Confirm: the old table structure is restored and the app starts cleanly.

     Python / Django example:
       1. Run: python manage.py migrate myapp 0042
       2. Deploy previous version.

     Rails example:
       1. Run: rails db:rollback STEP=1
       2. Deploy previous version.

     Feature flag (no DB change):
       1. Set FEATURE_NEW_CHECKOUT=false in environment and redeploy.
       2. No database changes needed.
-->

## Data impact

<!-- Will rolling back cause data loss?
     Which rows, tables, or records will be affected?
     If yes — what is the recovery plan? (backup restore, re-run job, manual fix)

     Example:
     - Rolling back deletes the `deleted_at` column. Any rows soft-deleted after
       deploy will appear un-deleted after rollback. Recovery: restore from backup
       taken at deploy time.
-->

## Estimated rollback time

<!-- How long does the rollback take end-to-end? Is there downtime?

     Example: ~5 minutes. No downtime — migration runs online. -->

## Who can execute the rollback?

<!-- Any special permissions or access needed?

     Example: Requires prod database credentials (stored in 1Password vault "Prod").
     Contact @ops-team for access. -->

## Verification after rollback

<!-- How do you confirm the rollback succeeded? Give a specific check.

     Example:
     - Run: SELECT COUNT(*) FROM users WHERE deleted_at IS NOT NULL;
     - Expected: 0 (column no longer exists)
     - Smoke test: log in as test@example.com — profile page loads without error.
-->
