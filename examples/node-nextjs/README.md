# Node / Next.js example customizations

Recommended quality gates:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm test:e2e
pnpm audit
```

Recommended extra security tests:

- Server-side authorization checks for each route/action
- Input validation tests for forms and API endpoints
- XSS checks for rendered user content
- CSRF/session behavior where applicable
