#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _long_path(p: Path) -> str:
    """Expand Windows 8.3 short names (e.g. ADMINI~1) to their long form.

    tempfile can hand back short-name paths that Git Bash's filesystem layer
    cannot resolve, making a directory look absent from bash.
    """
    s = str(p)
    if os.name != "nt":
        return s
    import ctypes
    buf = ctypes.create_unicode_buffer(32768)
    n = ctypes.windll.kernel32.GetLongPathNameW(s, buf, len(buf))
    return buf.value if n else s


_DRIVE_PREFIX_CACHE: dict[str, str] = {}


def _drive_prefix() -> str:
    """Detect how the `bash` on PATH mounts Windows drives.

    Git Bash/MSYS use /c, WSL uses /mnt/c. We ask bash to convert C:\\ and
    read back the prefix, so the test works under either.
    """
    if "prefix" in _DRIVE_PREFIX_CACHE:
        return _DRIVE_PREFIX_CACHE["prefix"]
    prefix = ""  # Git Bash/MSYS: C:\ -> /c
    for tool in ("cygpath", "wslpath"):
        try:
            out = subprocess.run(
                ["bash", "-lc", f'command -v {tool} >/dev/null 2>&1 && {tool} -u "C:\\\\"'],
                text=True, capture_output=True,
            ).stdout.strip().rstrip("/")
        except OSError:
            continue
        # out is like "/c" (Git Bash) or "/mnt/c" (WSL); prefix is everything before "/c"
        if out.endswith("/c"):
            prefix = out[: -len("/c")]
            break
    _DRIVE_PREFIX_CACHE["prefix"] = prefix
    return prefix


def bash_path(p: Path) -> str:
    """Convert a path to a form the `bash` on PATH accepts (Git Bash or WSL)."""
    if os.name != "nt":
        return str(p)
    # C:\Users\x -> <prefix>/c/Users/x, with 8.3 short names expanded first.
    s = _long_path(p).replace("\\", "/")
    if len(s) > 1 and s[1] == ":":
        drive = s[0].lower()
        rest = s[2:].lstrip("/")
        prefix = _drive_prefix()  # "" for /c, "/mnt" for /mnt/c
        s = f"{prefix}/{drive}/{rest}"
    return s


REQUIRED_FILES = [
    "README.md", "AGENTS.md", "CLAUDE.md", "CONTRIBUTING.md", "CHANGELOG.md", "LICENSE", ".gitignore",
    ".github/workflows/ci.yml", ".github/ISSUE_TEMPLATE/bug_report.md", ".github/ISSUE_TEMPLATE/feature_request.md",
    ".claude/settings.json",
    ".claude/agents/planner.md", ".claude/agents/test-architect.md",
    ".claude/agents/coder.md", ".claude/agents/tester.md", ".claude/agents/reviewer.md",
    ".claude/agents/design.md", ".claude/agents/verify.md", ".claude/agents/builder.md",
    ".claude/skills/ship/SKILL.md", ".claude/skills/plan-change/SKILL.md",
    ".claude/skills/test-change/SKILL.md", ".claude/skills/review-change/SKILL.md",
    ".claude/skills/release-check/SKILL.md", ".claude/skills/context-handoff/SKILL.md",
    ".claude/skills/resume-work/SKILL.md",
    ".claude/rules/coding-standards.md", ".claude/rules/testing.md", ".claude/rules/security.md",
    ".claude/rules/git-workflow.md", ".claude/rules/documentation.md",
    "templates/intent.md", "templates/plan.md", "templates/test-plan.md",
    "templates/implementation-log.md", "templates/test-report.md", "templates/review-report.md",
    "templates/merge-checklist.md", "templates/status.md", "templates/handoff.md", "templates/phase-comment.md",
    "scripts/create-run.sh", "scripts/check-branch.sh", "scripts/run-quality-gates.sh",
    "scripts/prevent-main-write.sh", "scripts/update-status.sh", "scripts/current-run.sh", "scripts/install.sh",
    "scripts/checkpoint.sh",
]

AGENTS = {
    "planner": {
        "model": "opus",
        "must_contain": ["Do not edit source files", "# Plan", "AGENTIC_SHIP_PHASE", "continue with plan"],
    },
    "test-architect": {
        "model": "opus",
        "must_contain": ["Do not edit implementation files", "# Test Plan", "status.md", "handoff.md"],
    },
    "coder": {
        "model": "sonnet",
        "must_contain": ["Implement only the approved plan", "permissionMode: acceptEdits", "handoff.md"],
    },
    "tester": {
        "model": "sonnet",
        "must_contain": ["Do not edit source files", "# Test Report", "Do not change tests to make them pass"],
    },
    "reviewer": {
        "model": "opus",
        "must_contain": ["Decision must be one of", "# Review Report", "Resume/handoff review"],
    },
    "design": {
        "model": "opus",
        "must_contain": ["Do not edit source files", "# Plan", "# Test Plan", "AGENTIC_SHIP_PHASE", "continue with plan"],
    },
    "verify": {
        "model": "opus",
        "must_contain": ["Do not edit source files", "# Test Report", "Do not change tests to make them pass", "# Review Report", "Decision must be one of"],
    },
    "builder": {
        "model": "sonnet",
        "must_contain": ["Implement only the approved plan", "permissionMode: acceptEdits", "handoff.md"],
    },
}


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def assert_exists() -> None:
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).exists()]
    assert not missing, f"Missing files: {missing}"


def assert_settings_are_valid() -> None:
    settings = json.loads(read(".claude/settings.json"))
    assert "permissions" in settings
    permissions = settings["permissions"]
    assert "deny" in permissions
    assert "ask" in permissions
    assert "allow" in permissions
    deny_text = "\n".join(permissions["deny"])
    assert ".env" in deny_text
    assert "git push origin main" in deny_text
    assert "git push origin master" in deny_text
    assert "--no-verify" in deny_text


def assert_readme_is_beginner_friendly() -> None:
    text = read("README.md")
    for phrase in [
        "Install into an existing project",
        "How to use the workflow",
        "Resume and context handoff",
        "GitHub publishing checklist",
        "/context-handoff",
        "/resume-work",
    ]:
        assert phrase in text, f"README missing {phrase!r}"


def assert_claude_imports_agents() -> None:
    claude = read("CLAUDE.md")
    assert "@AGENTS.md" in claude
    assert "/ship" in claude
    assert "Never merge automatically" in claude
    assert "Resume behavior" in claude
    assert "Context handoff behavior" in claude


def frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"---\n(.*?)\n---", text, flags=re.DOTALL)
    assert match, "Missing YAML-like frontmatter"
    data: dict[str, str] = {}
    for raw_line in match.group(1).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("-") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"')
    return data


def assert_agents_are_configured() -> None:
    for name, expected in AGENTS.items():
        path = f".claude/agents/{name}.md"
        text = read(path)
        fm = frontmatter(text)
        assert fm.get("name") == name
        assert fm.get("model") == expected["model"], f"{name} model mismatch"
        assert "permissionMode" in fm
        for required in expected["must_contain"]:
            assert required in text, f"{path} missing {required!r}"


def assert_skills_reference_pipeline_and_resume() -> None:
    text = read(".claude/skills/ship/SKILL.md")
    for word in ["planner", "test-architect", "coder", "tester", "reviewer", "release-check"]:
        assert word in text
    for artifact in [
        "intent.md", "plan.md", "test-plan.md", "implementation-log.md", "test-report.md",
        "review-report.md", "merge-checklist.md", "status.md", "handoff.md",
    ]:
        assert artifact in text
    assert "Never merge" in text
    assert "/context-handoff" in text
    assert "/resume-work" in text
    assert "latest-run.txt" in text

    handoff = read(".claude/skills/context-handoff/SKILL.md")
    resume = read(".claude/skills/resume-work/SKILL.md")
    assert "context indicator" in handoff
    assert "handoff.md" in handoff
    assert "status.md" in handoff
    assert "continue with plan" in resume
    assert "next unchecked phase" in resume


def assert_templates_have_required_headings() -> None:
    required = {
        "templates/plan.md": ["AGENTIC_SHIP_PHASE", "## Current status", "## Phase tracker", "## Goal", "## Security considerations", "## Acceptance criteria", "## Resume notes"],
        "templates/test-plan.md": ["AGENTIC_SHIP_PHASE", "## Current status", "## Security tests", "## Required commands", "## Pass/fail criteria"],
        "templates/test-report.md": ["AGENTIC_SHIP_PHASE", "## Summary", "## Commands run", "## Recommendation"],
        "templates/review-report.md": ["AGENTIC_SHIP_PHASE", "## Decision", "## Security review", "## Merge recommendation"],
        "templates/status.md": ["AGENTIC_SHIP_STATUS", "## Current phase", "## Phase tracker", "## Continue instructions"],
        "templates/handoff.md": ["AGENTIC_SHIP_HANDOFF", "## Current task", "## Exact next step", "## How to resume in a new session"],
    }
    for path, headings in required.items():
        text = read(path)
        for heading in headings:
            assert heading in text, f"{path} missing heading {heading}"


def assert_scripts_are_executable() -> None:
    # NTFS does not carry Unix exec bits, so this check is meaningless on a
    # fresh Windows checkout. The bit is enforced on Linux/Mac (incl. CI),
    # where it actually matters for running the scripts.
    if os.name == "nt":
        return
    for path in [
        "scripts/create-run.sh", "scripts/check-branch.sh", "scripts/run-quality-gates.sh",
        "scripts/prevent-main-write.sh", "scripts/update-status.sh", "scripts/current-run.sh", "scripts/install.sh",
    ]:
        full = ROOT / path
        assert full.stat().st_mode & 0o111, f"{path} is not executable"


def assert_create_run_and_status_work() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp) / "kit"
        ignore = shutil.ignore_patterns(".agent-runs", "__pycache__", ".pytest_cache")
        shutil.copytree(ROOT, temp_root, ignore=ignore)
        result = subprocess.run(
            ["bash", "scripts/create-run.sh", "Add password reset flow"],
            cwd=temp_root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        run_dir = temp_root / result.stdout.strip()
        assert run_dir.exists(), result.stdout
        assert (temp_root / ".agent-runs/latest-run.txt").read_text(encoding="utf-8").strip() == result.stdout.strip()
        for name in [
            "intent.md", "plan.md", "test-plan.md", "implementation-log.md", "test-report.md",
            "review-report.md", "merge-checklist.md", "status.md", "handoff.md",
        ]:
            assert (run_dir / name).exists(), f"missing generated {name}"
        assert "Add password reset flow" in (run_dir / "intent.md").read_text(encoding="utf-8")
        assert "AGENTIC_SHIP_STATUS" in (run_dir / "status.md").read_text(encoding="utf-8")
        assert "AGENTIC_SHIP_HANDOFF" in (run_dir / "handoff.md").read_text(encoding="utf-8")

        rel_run_dir = run_dir.relative_to(temp_root).as_posix()
        subprocess.run(
            ["bash", "scripts/update-status.sh", rel_run_dir, "1-plan", "Create test-plan.md next."],
            cwd=temp_root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        status = (run_dir / "status.md").read_text(encoding="utf-8")
        assert "phase: 1-plan" in status
        assert "Create test-plan.md next." in status

        current = subprocess.run(
            ["bash", "scripts/current-run.sh"],
            cwd=temp_root,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        ).stdout.strip()
        assert current == rel_run_dir


def assert_install_script_copies_expected_files() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "project"
        target.mkdir()
        subprocess.run(
            ["bash", "scripts/install.sh", bash_path(target)],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        for path in [".claude", "AGENTS.md", "CLAUDE.md", "templates", "scripts"]:
            assert (target / path).exists(), f"install missing {path}"
        assert (target / ".claude/skills/resume-work/SKILL.md").exists()


def main() -> None:
    assert_exists()
    assert_settings_are_valid()
    assert_readme_is_beginner_friendly()
    assert_claude_imports_agents()
    assert_agents_are_configured()
    assert_skills_reference_pipeline_and_resume()
    assert_templates_have_required_headings()
    assert_scripts_are_executable()
    assert_create_run_and_status_work()
    assert_install_script_copies_expected_files()
    print("All template structure tests passed.")


if __name__ == "__main__":
    main()
