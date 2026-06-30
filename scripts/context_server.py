#!/usr/bin/env python
"""
ship-kit MCP context server — serves .ship-context/ files as prompt-cacheable tools.

Implements the MCP stdio (JSON-RPC 2.0) protocol with no external dependencies.
Resolves the project root from the working directory at request time, so it
works whether installed globally (~/.claude/scripts/) or per-project (scripts/).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


def _project_root() -> Path:
    """Return the git repo root, or CWD if not in a git repo."""
    cwd = Path(os.getcwd())
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, cwd=cwd
        )
        if result.returncode == 0:
            return Path(result.stdout.strip())
    except Exception:
        pass
    return cwd


def _read_context_file(name: str) -> str:
    root = _project_root()
    path = root / ".ship-context" / name
    if path.is_file():
        return path.read_text(encoding="utf-8")
    return (
        f"# {name}\n\nNot found. Run `bash scripts/build-context.sh` "
        "(or `bash ~/.claude/scripts/build-context.sh`) to generate.\n"
    )


TOOLS = [
    {
        "name": "get_index",
        "description": (
            "Returns the codebase INDEX.md — repo overview, languages, entry points, "
            "key directories. Read this first before any file exploration. "
            "Prompt-cached: 10x cheaper than a file read on repeated calls."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_structure",
        "description": (
            "Returns structure.md — full directory tree with per-file sizes and "
            "first-comment descriptions. Use to locate files without Glob sweeps. "
            "Prompt-cached: 10x cheaper than a file read on repeated calls."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_symbols",
        "description": (
            "Returns symbols.md — functions, classes, and exports across the codebase "
            "(grep-based, no LLM). Use to find where a symbol is defined. "
            "Prompt-cached: 10x cheaper on repeated calls."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_recent",
        "description": (
            "Returns recent-changes.md — last 20 commits, diff stats for the last 5 "
            "commits, and current uncommitted changes. Use to understand what has been "
            "touched recently. Prompt-cached: 10x cheaper on repeated calls."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
]

FILE_MAP = {
    "get_index": "INDEX.md",
    "get_structure": "structure.md",
    "get_symbols": "symbols.md",
    "get_recent": "recent-changes.md",
}


def _respond(req_id, result):
    msg = json.dumps({"jsonrpc": "2.0", "id": req_id, "result": result})
    sys.stdout.write(msg + "\n")
    sys.stdout.flush()


def _error(req_id, code, message):
    msg = json.dumps({
        "jsonrpc": "2.0", "id": req_id,
        "error": {"code": code, "message": message},
    })
    sys.stdout.write(msg + "\n")
    sys.stdout.flush()


def handle(req: dict) -> None:
    req_id = req.get("id")
    method = req.get("method", "")

    if method == "initialize":
        _respond(req_id, {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "ship-context", "version": "1.0.0"},
        })

    elif method == "tools/list":
        _respond(req_id, {"tools": TOOLS})

    elif method == "tools/call":
        params = req.get("params", {})
        tool_name = params.get("name", "")
        if tool_name not in FILE_MAP:
            _error(req_id, -32602, f"Unknown tool: {tool_name}")
            return
        content = _read_context_file(FILE_MAP[tool_name])
        _respond(req_id, {
            "content": [{"type": "text", "text": content}],
            "isError": False,
        })

    elif method == "notifications/initialized":
        pass  # no response needed for notifications

    else:
        if req_id is not None:
            _error(req_id, -32601, f"Method not found: {method}")


def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            _error(None, -32700, f"Parse error: {exc}")
            continue
        try:
            handle(req)
        except Exception as exc:
            _error(req.get("id"), -32603, f"Internal error: {exc}")


if __name__ == "__main__":
    main()
