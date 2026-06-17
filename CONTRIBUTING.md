# Contributing

Thanks for improving Agentic Ship Kit.

## Local checks

Run these before opening a PR:

```bash
python3 tests/test_template_structure.py
./scripts/run-quality-gates.sh
```

## Development rules

- Keep the kit easy for beginners to understand.
- Do not add dependencies unless needed.
- Keep agents, skills, templates, and tests in sync.
- Update `README.md` when user-facing behavior changes.
- Update `tests/test_template_structure.py` when new required files are added.

## Pull request checklist

- [ ] README updated if behavior changed
- [ ] Tests updated if structure changed
- [ ] `python3 tests/test_template_structure.py` passes
- [ ] `./scripts/run-quality-gates.sh` passes
