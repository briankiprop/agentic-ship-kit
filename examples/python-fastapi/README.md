# Python / FastAPI example customizations

Recommended quality gates:

```bash
ruff check .
ruff format --check .
mypy .
pytest
pip-audit
```

Recommended extra security tests:

- Authenticated and unauthenticated API calls
- Authorization tests for user-owned resources
- Pydantic validation tests
- SQL injection regression tests where raw queries exist
