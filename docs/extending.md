# Extending the Agentic Ship Kit

The kit ships with a fixed set of agents, skills, and rules. You can extend all three without modifying the core files — just add to the same directories.

---

## Adding a custom agent

Create a new file in `.claude/agents/`:

```text
.claude/agents/my-agent.md
```

Minimum structure:

```markdown
---
name: my-agent
description: What this agent does and when to invoke it.
model: claude-sonnet-4-6
---

# My Agent

You are a specialist in X. Your job is to Y.

## Rules

- Never edit files outside of Z.
- Always produce a summary at the end.

## Output

Return your findings as a markdown report.
```

Key fields:
- `model`: use `claude-opus-4-8` for planning/review, `claude-sonnet-4-6` for implementation.
- Add `tools: [Read, Grep, Glob, Bash]` to restrict tool access (recommended for read-only agents).
- Add `disallowedTools: [Edit, Write]` to hard-block file writes.

**Example: a dependency-audit agent**

```markdown
---
name: dep-auditor
description: Audit all direct dependencies for known vulnerabilities and licence issues. Invoke before release or when adding new packages.
model: claude-sonnet-4-6
tools: [Read, Grep, Glob, Bash]
---

# Dependency Auditor

Check every package in package.json / pyproject.toml / Gemfile for:
1. Known CVEs (run npm audit / pip-audit / bundle audit).
2. Licence compatibility with the project licence.
3. Packages that are abandonware (no release in 2+ years).

Return a markdown table: package | version | issue | severity | recommendation.
```

---

## Adding a custom skill

Create a new folder and `SKILL.md` in `.claude/skills/`:

```text
.claude/skills/my-skill/SKILL.md
```

Users invoke it with `/my-skill`.

Minimum structure:

```markdown
---
name: my-skill
description: One-line description shown in the skill list.
argument-hint: "[optional arguments]"
disable-model-invocation: true
---

# My Skill

## Step 1: ...

## Step 2: ...
```

`disable-model-invocation: true` means the skill is a set of instructions Claude follows directly — it does not auto-invoke a model. Leave it out only if you want the skill to behave like a prompt.

**Example: a `/security-scan` skill**

```markdown
---
name: security-scan
description: Run a focused security audit on the current diff or a named file.
argument-hint: "[file or area to audit]"
disable-model-invocation: true
---

# Security Scan

## Step 1: Scope

If the user named a file, audit that file only. Otherwise audit the current `git diff`.

## Step 2: Check

Apply every rule in `.claude/rules/security.md`. For each finding record:
- File and line number
- Rule violated
- Severity (critical / high / medium / low)
- Suggested fix

## Step 3: Report

Write findings to `.agent-runs/<run-id>/security-scan.md`. If no run is active, print to the terminal.
```

---

## Adding a custom rule

Create a markdown file in `.claude/rules/`:

```text
.claude/rules/my-rule.md
```

Rules are loaded automatically by all agents. Keep each rule file focused on one concern.

**Example: a rate-limiting rule**

```markdown
# Rate Limiting Rules

Every user-facing endpoint must have rate limiting applied.

- Use the shared `rateLimiter` middleware — do not implement ad-hoc counters.
- Authentication endpoints: max 5 requests per minute per IP.
- API endpoints: max 100 requests per minute per authenticated user.
- Never disable rate limiting without explicit approval in the plan's security section.
```

---

## Replacing a built-in agent

To replace a built-in agent (e.g. `coder`) with your own version, create a file with the same name:

```text
.claude/agents/coder.md
```

Your file takes precedence over the kit's version. Back up the original first if you want to be able to restore it.

---

## Sharing extensions across projects

Put your custom agents, skills, and rules in a separate repository and add them during install using `install.sh`. Or document them in your project's `AGENTS.md` so the team knows they exist.
