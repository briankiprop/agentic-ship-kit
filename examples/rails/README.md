# Rails example customizations

Recommended quality gates:

```bash
bundle exec rubocop
bundle exec brakeman
bin/rails test
bin/rails test:system
```

Recommended extra security tests:

- Controller authorization tests
- Model validation tests
- CSRF behavior for non-API controllers
- Strong parameters tests for sensitive attributes
