# Testing Rules

Every meaningful change needs tests.

## Minimum expectations

- New behavior requires tests.
- Bug fixes require regression tests.
- Security-sensitive changes require negative tests.
- Refactors must preserve existing behavior.
- If tests cannot be added, explain why in the test report.

## Test report honesty

- Never say tests passed if they were not run.
- Never hide failing tests.
- Never remove tests just to make the suite pass.
- Record command output or the important part of it.
