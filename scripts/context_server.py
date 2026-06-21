#!/usr/bin/env python
"""
ship-kit MCP context server — serves .ship-context/ files as prompt-cacheable tools.

Implements the MCP stdio (JSON-RPC 2.0) protocol with no external dependencies.
Register in .claude/settings.json under "mcpServers" and Claude Code will
start this server automatically and make its tools available to agents.

Tool responses that stay unchanged within a 5-minute window hit the Anthropic
prompt cache at 0.1x cost — roughly 90% savings on repeated context reads
vs agents calling Read(.ship-context/INDEX.md) directly.

Tools exposed:
  get_index()      → .ship-context/INDEX.md
  get_structure()  → .ship-context/structure.md
  get_symbols()    → .ship-context/symbols.md
  get_recent()     → .ship-context/recent-changes.md
"""
import json
import os
import sys
from pathlib import Path

# Claude Code sets CLAUDE_PROJECT_DIR automatically for MCP servers.
PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
CONTEXT_DIR = PROJECT_DIR / ".ship-context"

SERVER_INFO = {"name": "ship-context", "version": "1.0"}
PROTOCOL_VERSION = "2024-11-05"

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
            "Returns symbols.md — all functions, classes, and exports extracted by "
            "grep across the codebase. Use to find where a symbol is defined without "
            "Grep sweeps. Prompt-cached: 10x cheaper on repeated calls."
        ),
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "get_recent",
        "description": (
            "Returns recent-changes.md — last 20 commits, diff stats for the last "
            "5 commits, and current uncommitted changes. Use to understand what has "
            "been touched recently. Prompt-cached: 10x cheaper on repeated calls."
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


def _read_context_file(filename: str) -> str:
    path = CONTEXT_DIR / filename
    if not CONTEXT_DIR.exists():
        return (
            "Context cache not built yet. "
            "Run: bash scripts/build-context.sh\n"
            f"Expected directory: {CONTEXT_DIR}"
        )
    if not path.exists():
        return (
            f"File not found: {path}\n"
            "Run: bash scripts/build-context.sh --force"
        )
    try:
        return path.read_text(encoding="utf-8")
    except Exception as e:
        return f"Error reading {path}: {e}"


def _respond(req_id, result):
    out = json.dumps({"jsonrpc": "2.0", "id": req_id, "result": result})
    sys.stdout.write(out + "\n")
    sys.stdout.flush()


def _error(req_id, code: int, message: str):
    out = json.dumps({
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": code, "message": message},
    })
    sys.stdout.write(out + "\n")
    sys.stdout.flush()


def handle(msg: dict):
    method = msg.get("method", "")
    req_id = msg.get("id")

    if method == "initialize":
        _respond(req_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": SERVER_INFO,
        })

    elif method == "notifications/initialized":
        pass  # no response needed for notifications

    elif method == "tools/list":
        _respond(req_id, {"tools": TOOLS})

    elif method == "tools/call":
        params = msg.get("params", {})
        name = params.get("name", "")
        if name not in FILE_MAP:
            _error(req_id, -32602, f"Unknown tool: {name}")
            return
        content = _read_context_file(FILE_MAP[name])
        _respond(req_id, {
            "content": [{"type": "text", "text": content}],
            "isError": False,
        })

    elif method == "ping":
        _respond(req_id, {})

    else:
        if req_id is not None:
            _error(req_id, -32601, f"Method not found: {method}")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError as e:
            sys.stderr.write(f"[ship-context] JSON parse error: {e}\n")
            continue
        try:
            handle(msg)
        except Exception as e:
            sys.stderr.write(f"[ship-context] Handler error: {e}\n")


if __name__ == "__main__":
    main()
