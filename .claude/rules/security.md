# Security Rules

Apply to all code changes.

## Required checks

- Validate external input.
- Enforce server-side authorization.
- Do not expose secrets in logs, errors, tests, snapshots, or docs.
- Use safe database query patterns.
- Check permissions on every user-owned resource.
- Avoid leaking whether a user/email/account exists unless product requirements allow it.
- Add regression tests for security fixes.
- Check dependency risk when adding new packages.

## Blockers

Block the change if it:

- Stores plaintext passwords or tokens.
- Logs credentials, session cookies, reset tokens, API keys, or private data.
- Bypasses authentication or authorization.
- Disables CSRF, CORS, rate limiting, or validation without explicit approval.
- Adds a dependency with known critical vulnerabilities without justification.
