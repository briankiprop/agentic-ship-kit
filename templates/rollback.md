# Rollback Plan

<!-- Fill this out for any change that touches data models, migrations, payments,
     or other hard-to-reverse operations. Add it to plan.md and merge-checklist.md. -->

## Is this change reversible?

- [ ] Yes — describe how below.
- [ ] Partially — some steps are irreversible; describe which ones and why.
- [ ] No — explain why and what the mitigation is.

## Rollback steps

<!-- Write the exact commands or steps to undo this change after it is deployed.
     Be specific enough that someone unfamiliar with the change can execute them
     under pressure.

     Example for a database migration:
       1. Run: rails db:rollback STEP=1
          or: python manage.py migrate myapp 0042
       2. Deploy the previous application version.
       3. Verify: check that the old column/table is gone and the app starts cleanly.

     Example for a feature flag:
       1. Set FEATURE_NEW_CHECKOUT=false in the environment and redeploy.
       2. No database changes to undo.
-->

## Data impact

<!-- Will rollback cause data loss? Which rows, columns, or records?
     If yes, describe the recovery plan (restore from backup, re-run job, etc.). -->

## Estimated rollback time

<!-- How long does rollback take? Is there downtime? -->

## Who can execute the rollback?

<!-- Any permission or access requirements (prod DB access, deploy key, etc.)? -->

## Verification after rollback

<!-- How do you confirm the rollback succeeded?
     Include a specific check or smoke test. -->
