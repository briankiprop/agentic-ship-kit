#!/usr/bin/env python3
"""
Telegram poller for Agentic Ship Kit.
Polls getUpdates, handles /ship /projects /status /stop /help commands.
Runs on Windows Git Bash, WSL, macOS, Linux.
"""
import io
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Force UTF-8 stdout so Unicode doesn't crash on Windows cp1252 terminals
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# ── Config paths ────────────────────────────────────────────────────────────
HOME          = os.path.expanduser("~")
CONFIG_FILE   = os.path.join(HOME, ".agentic-ship-telegram")
PROJECTS_FILE = os.path.join(HOME, ".agentic-ship-projects")
OFFSET_FILE   = os.path.join(HOME, ".agentic-ship-telegram-offset")
LOCK_FILE     = os.path.join(HOME, ".agentic-ship-running.pid")
APPROVAL_FILE = os.path.join(HOME, ".agentic-ship-approval")
POLLER_LOCK   = os.path.join(HOME, ".agentic-ship-poller.pid")
RUNS_DIR      = os.path.join(HOME, ".agentic-ship-runs")
SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))


def find_git_bash():
    """Find the full Git Bash executable that supports /d/ drive mounts."""
    candidates = [
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files (x86)\Git\bin\bash.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    # Fallback: use whatever bash is on PATH
    import shutil
    return shutil.which("bash") or "bash"


def to_bash_path(win_path):
    """Convert Windows path to Git Bash POSIX path (e.g. D:\foo -> /d/foo)."""
    import subprocess as _sp
    bash = find_git_bash()
    try:
        result = _sp.run([bash, "-c", f"cygpath -u '{win_path}'"],
                         capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    # Manual fallback: D:\foo\bar -> /d/foo/bar
    p = win_path.replace("\\", "/")
    if len(p) >= 2 and p[1] == ":":
        p = "/" + p[0].lower() + p[2:]
    return p

# ── Load config ──────────────────────────────────────────────────────────────
def load_config():
    cfg = {}
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            cfg[k.strip()] = v.strip().strip('"').strip("'")
    return cfg

# ── Telegram helpers ─────────────────────────────────────────────────────────
def tg_request(token, method, params):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(params).encode()
    try:
        req = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(req, timeout=35) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"[tg] {method} error: {e}", flush=True)
        return {"ok": False}

def send(token, chat_id, text):
    tg_request(token, "sendMessage", {"chat_id": chat_id, "text": text})

def get_updates(token, offset, timeout=30):
    url = (f"https://api.telegram.org/bot{token}/getUpdates"
           f"?offset={offset}&timeout={timeout}&allowed_updates=message")
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout + 5) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"[tg] getUpdates error: {e}", flush=True)
        return {"ok": False, "result": []}

# ── Project registry ─────────────────────────────────────────────────────────
def load_projects():
    projects = {}
    if not os.path.exists(PROJECTS_FILE):
        return projects
    with open(PROJECTS_FILE) as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                alias, _, path = line.partition("=")
                projects[alias.strip()] = path.strip()
    return projects

# ── Process management ────────────────────────────────────────────────────────
def pid_exists(pid):
    """Cross-platform process existence check."""
    try:
        if sys.platform == "win32":
            import ctypes
            SYNCHRONIZE = 0x00100000
            handle = ctypes.windll.kernel32.OpenProcess(SYNCHRONIZE, False, pid)
            if handle:
                ctypes.windll.kernel32.CloseHandle(handle)
                return True
            return False
        else:
            os.kill(pid, 0)
            return True
    except (OSError, AttributeError):
        return False


def run_headless_active():
    """Check if run-headless.sh is running by scanning process list."""
    try:
        r = subprocess.run(
            ["tasklist", "/FO", "CSV", "/NH"],
            capture_output=True, text=True, timeout=5
        )
        # Look for bash processes running run-headless.sh
        for line in r.stdout.splitlines():
            if "bash" in line.lower():
                # Get PID from CSV: "bash.exe","1234",...
                parts = line.strip('"').split('","')
                if len(parts) >= 2:
                    try:
                        pid = int(parts[1])
                        cmd = (subprocess.run(
                            ["wmic", "process", "where", f"ProcessId={pid}",
                             "get", "CommandLine", "/format:value"],
                            capture_output=True, text=True, timeout=5
                        ).stdout)
                        if "run-headless.sh" in cmd:
                            return True, pid
                    except (ValueError, Exception):
                        pass
    except Exception:
        pass
    return False, None


def is_running():
    # First check lock file
    if os.path.exists(LOCK_FILE):
        try:
            content = open(LOCK_FILE).read().strip()
            if content:
                pid = int(content)
                if pid_exists(pid):
                    return True, pid
        except (ValueError, OSError):
            pass
        # Lock file exists but PID is stale — verify via process scan
        active, pid = run_headless_active()
        if active:
            # Update lock file with correct PID
            try:
                with open(LOCK_FILE, "w") as f:
                    f.write(str(pid))
            except OSError:
                pass
            return True, pid
        # Stale lock — remove it
        try:
            os.remove(LOCK_FILE)
        except OSError:
            pass
        return False, None
    # No lock file — still check process list in case script started but hasn't written it yet
    return run_headless_active()

def kill_pid(pid):
    """Cross-platform process termination."""
    try:
        if sys.platform == "win32":
            import ctypes
            PROCESS_TERMINATE = 0x0001
            handle = ctypes.windll.kernel32.OpenProcess(PROCESS_TERMINATE, False, pid)
            if handle:
                ctypes.windll.kernel32.TerminateProcess(handle, 1)
                ctypes.windll.kernel32.CloseHandle(handle)
        else:
            os.kill(pid, 15)
    except (OSError, AttributeError):
        pass


def stop_running():
    running, pid = is_running()
    if running and pid:
        kill_pid(pid)
        try:
            os.remove(LOCK_FILE)
        except OSError:
            pass
        return True
    if os.path.exists(LOCK_FILE):
        try:
            os.remove(LOCK_FILE)
        except OSError:
            pass
    return False

# ── Command handlers ──────────────────────────────────────────────────────────
def handle_projects(token, chat_id):
    projects = load_projects()
    if not projects:
        send(token, chat_id,
             "No projects registered yet.\n\n"
             "On your PC run:\n"
             "bash scripts/register-project.sh /path/to/project myapp")
        return
    lines = "\n".join(f"  {a} → {p}" for a, p in projects.items())
    send(token, chat_id, f"Registered projects:\n{lines}\n\nUse: /ship <alias> <task>")

def handle_status(token, chat_id):
    # Check if waiting for plan approval first
    if os.path.exists(APPROVAL_FILE):
        try:
            state = open(APPROVAL_FILE).read().strip()
            if state == "waiting":
                send(token, chat_id,
                     "A plan is waiting for your approval.\n\n"
                     "/approve — proceed with coding\n"
                     "/reject — cancel the task\n"
                     "/feedback <notes> — approve with changes")
                return
        except OSError:
            pass
    running, pid = is_running()
    if running:
        send(token, chat_id, f"Task is currently running (PID {pid})")
    else:
        send(token, chat_id, "No task is currently running.")

def handle_stop(token, chat_id):
    if stop_running():
        send(token, chat_id, "Task stopped.")
    else:
        send(token, chat_id, "No running task found.")

def handle_ship(token, chat_id, args):
    projects = load_projects()

    # Parse: /ship [alias] task...
    parts = args.strip().split(None, 1)
    if not parts:
        send(token, chat_id, "Usage: /ship <project> <task>\nExample: /ship hfm-trader add a login page")
        return

    first = parts[0]
    rest  = parts[1] if len(parts) > 1 else ""

    if first in projects:
        project_dir = projects[first]
        task = rest
    elif len(projects) == 1:
        # Only one project — use it, treat whole args as task
        project_dir = list(projects.values())[0]
        task = args.strip()
    else:
        send(token, chat_id,
             f"Project not found: {first}\n\n"
             f"Register it on your PC:\n"
             f"bash scripts/register-project.sh /path/to/project {first}\n\n"
             f"Or list registered projects: /projects")
        return

    if not task:
        send(token, chat_id, "Please include a task. Example:\n/ship hfm-trader add a login page")
        return

    running, pid = is_running()
    if running:
        send(token, chat_id, f"A task is already running (PID {pid}). Send /stop first.")
        return

    claude_path, _ = find_claude()
    if not claude_path:
        send(token, chat_id,
             "Claude Code CLI is not installed.\n\n"
             "On your PC run:\n"
             "  npm install -g @anthropic-ai/claude-code\n\n"
             "Then restart the listener.")
        return

    project_name = os.path.basename(project_dir.rstrip("/\\"))
    send(token, chat_id, f"Starting task on {project_name}\nTask: {task}")
    print(f"[poll] Launching: {task} in {project_dir}", flush=True)

    os.makedirs(RUNS_DIR, exist_ok=True)
    run_script  = to_bash_path(os.path.join(SCRIPT_DIR, "run-headless.sh"))
    bash_proj   = to_bash_path(project_dir)
    log_slug    = re.sub(r"[^a-z0-9]+", "-", task.lower())[:40].strip("-")
    log_file    = os.path.join(RUNS_DIR, f"{time.strftime('%Y-%m-%d-%H%M%S')}-{log_slug}.log")

    git_bash = find_git_bash()
    # Pass script path directly to git_bash — avoid nested `bash` call which resolves
    # to usr\bin\bash.exe (doesn't mount /d/ drives) instead of bin\bash.exe
    run_script_win = os.path.join(SCRIPT_DIR, "run-headless.sh")
    print(f"[poll] bash={git_bash} script={run_script_win} proj={bash_proj}", flush=True)

    with open(log_file, "w") as lf:
        proc = subprocess.Popen(
            [git_bash, run_script_win, task, bash_proj],
            stdout=lf, stderr=lf,
            start_new_session=True
        )

    # Write lock file immediately from the poller so subsequent /ship or /status
    # commands see the task as running before run-headless.sh has a chance to write it.
    try:
        with open(LOCK_FILE, "w") as lf2:
            lf2.write(str(proc.pid))
    except OSError:
        pass
    print(f"[poll] launched PID {proc.pid}, log {log_file}", flush=True)

def handle_approve(token, chat_id, feedback=None):
    if not os.path.exists(APPROVAL_FILE):
        send(token, chat_id, "No plan is waiting for approval.")
        return
    try:
        current = open(APPROVAL_FILE).read().strip()
    except OSError:
        send(token, chat_id, "Could not read approval state.")
        return
    if current != "waiting":
        send(token, chat_id, "No plan is currently waiting for approval.")
        return
    try:
        with open(APPROVAL_FILE, "w") as f:
            if feedback:
                f.write(f"feedback:{feedback}")
                send(token, chat_id, f"Plan approved with feedback:\n{feedback}\n\nCoding will begin now...")
            else:
                f.write("approved")
                send(token, chat_id, "Plan approved! Coding will begin now...")
    except OSError as e:
        send(token, chat_id, f"Error writing approval: {e}")


def handle_reject(token, chat_id):
    if not os.path.exists(APPROVAL_FILE):
        send(token, chat_id, "No plan is waiting for approval.")
        return
    try:
        current = open(APPROVAL_FILE).read().strip()
    except OSError:
        send(token, chat_id, "Could not read approval state.")
        return
    if current != "waiting":
        send(token, chat_id, "No plan is currently waiting for approval.")
        return
    try:
        with open(APPROVAL_FILE, "w") as f:
            f.write("reject")
        send(token, chat_id, "Task rejected and cancelled.")
    except OSError as e:
        send(token, chat_id, f"Error writing rejection: {e}")


def handle_help(token, chat_id):
    send(token, chat_id,
         "Agentic Ship Kit Commands\n\n"
         "/ship <project> <task> — Start a task\n"
         "/projects — List registered projects\n"
         "/status — Check if a task is running\n"
         "/stop — Stop the current task\n"
         "/help — Show this message\n\n"
         "Plan approval (when Claude sends you a plan):\n"
         "/approve — Proceed with coding\n"
         "/reject — Cancel the task\n"
         "/feedback <notes> — Approve with changes\n\n"
         "Examples:\n"
         "/ship hfm-trader add a login page\n"
         "/ship hfm-trader fix the checkout bug")

# ── Claude CLI check + auto-install ──────────────────────────────────────────
def find_claude():
    """Return (path, version) or (None, None) if not found."""
    import shutil
    path = shutil.which("claude")
    if path:
        try:
            r = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=10)
            version = r.stdout.strip() or r.stderr.strip() or "unknown version"
            return path, version.splitlines()[0]
        except Exception:
            return path, "unknown version"
    return None, None


def install_claude(token, chat_id):
    """Try to install Claude Code CLI via npm. Returns (ok, message)."""
    import shutil
    npm = shutil.which("npm")
    if not npm:
        return False, "npm not found — install Node.js from https://nodejs.org then run: npm install -g @anthropic-ai/claude-code"
    print("[setup] Installing Claude Code CLI via npm...", flush=True)
    send(token, chat_id, "Installing Claude Code CLI — this takes about a minute...")
    try:
        r = subprocess.run(
            [npm, "install", "-g", "@anthropic-ai/claude-code"],
            capture_output=True, text=True, timeout=180
        )
        if r.returncode == 0:
            path, version = find_claude()
            if path:
                return True, f"Installed: {version}"
            return False, "npm install succeeded but 'claude' still not found — try opening a new terminal"
        return False, f"npm install failed:\n{r.stderr.strip()[:300]}"
    except subprocess.TimeoutExpired:
        return False, "npm install timed out — run manually: npm install -g @anthropic-ai/claude-code"
    except Exception as e:
        return False, f"Install error: {e}"


def _startup_status(token, chat_id, projects):
    """Check claude CLI, auto-install if missing, return startup status message."""
    claude_path, claude_version = find_claude()

    if not claude_path:
        ok, msg = install_claude(token, chat_id)
        if ok:
            claude_path, claude_version = find_claude()
            claude_line = f"Claude Code CLI: {claude_version}"
        else:
            claude_line = f"Claude Code CLI: NOT FOUND\n{msg}"
    else:
        claude_line = f"Claude Code CLI: {claude_version}"

    if projects:
        proj_lines = "\n".join(f"  {a} = {p}" for a, p in projects.items())
        proj_section = f"Registered projects:\n{proj_lines}"
    else:
        proj_section = ("No projects registered yet.\n"
                        "On your PC run:\n"
                        "  bash scripts/register-project.sh /path/to/project myapp")

    if claude_path and projects:
        ready = "Ready! Send /help to see commands."
    elif claude_path:
        ready = "Claude CLI is ready. Register a project to start shipping from Telegram."
    else:
        ready = "Fix the Claude Code CLI first, then restart the listener."

    return (
        "Agentic Ship Kit online\n\n"
        f"{claude_line}\n\n"
        f"{proj_section}\n\n"
        f"{ready}"
    )


# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    cfg     = load_config()
    token   = cfg.get("TELEGRAM_BOT_TOKEN", "")
    chat_id = cfg.get("TELEGRAM_CHAT_ID", "")

    if not token or not chat_id:
        print("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing in config.", file=sys.stderr)
        sys.exit(1)

    # Load saved offset
    offset = 0
    if os.path.exists(OFFSET_FILE):
        try:
            offset = int(open(OFFSET_FILE).read().strip())
        except ValueError:
            offset = 0

    # Single-instance guard
    if os.path.exists(POLLER_LOCK):
        try:
            pid = int(open(POLLER_LOCK).read().strip())
            if pid_exists(pid):
                print(f"Poller already running (PID {pid}). Stop it first.", file=sys.stderr)
                sys.exit(1)
            os.remove(POLLER_LOCK)
        except (ValueError, OSError):
            try:
                os.remove(POLLER_LOCK)
            except OSError:
                pass
    with open(POLLER_LOCK, "w") as f:
        f.write(str(os.getpid()))

    print(f"Agentic Ship Kit — Telegram poller started.", flush=True)
    print(f"Listening for commands in chat {chat_id} ...", flush=True)

    projects = load_projects()
    if projects:
        print("Registered projects:", flush=True)
        for a, p in projects.items():
            print(f"  {a} -> {p}", flush=True)
    else:
        print("No projects registered. Run register-project.sh first.", flush=True)

    # Check for claude CLI and auto-install if missing, then send full status
    send(token, chat_id, _startup_status(token, chat_id, projects))

    # Drain ALL pending messages: use offset=0 to fetch everything Telegram has
    # queued, advance past them without acting. This prevents stale /ship commands
    # from re-firing every time the poller restarts.
    drain = get_updates(token, 0, timeout=0)
    if drain.get("ok") and drain.get("result"):
        for upd in drain["result"]:
            uid = upd.get("update_id", 0)
            if uid > offset:
                offset = uid
        with open(OFFSET_FILE, "w") as f:
            f.write(str(offset))
        print(f"[poll] Drained {len(drain['result'])} queued message(s) on startup (offset now {offset}).", flush=True)
    else:
        print(f"[poll] No queued messages on startup (offset {offset}).", flush=True)

    while True:
        result = get_updates(token, offset + 1, timeout=30)
        if not result.get("ok"):
            time.sleep(5)
            continue

        for update in result.get("result", []):
            uid  = update.get("update_id", 0)
            offset = uid
            with open(OFFSET_FILE, "w") as f:
                f.write(str(offset))

            msg  = update.get("message", {})
            text = msg.get("text", "").strip()
            from_chat = str(msg.get("chat", {}).get("id", ""))

            if not text:
                continue

            # Security: only respond to configured chat
            if from_chat != str(chat_id):
                print(f"[poll] Ignoring message from unknown chat {from_chat}", flush=True)
                continue

            print(f"[poll] Received: {text}", flush=True)

            if text.startswith("/approve"):
                feedback = text[len("/approve"):].strip() or None
                handle_approve(token, chat_id, feedback)
            elif text.startswith("/reject"):
                handle_reject(token, chat_id)
            elif text.lower().startswith("/feedback "):
                notes = text[len("/feedback"):].strip()
                handle_approve(token, chat_id, feedback=notes)
            elif text.startswith("/projects"):
                handle_projects(token, chat_id)
            elif text.startswith("/status"):
                handle_status(token, chat_id)
            elif text.startswith("/stop"):
                handle_stop(token, chat_id)
            elif text.startswith("/help"):
                handle_help(token, chat_id)
            elif text.startswith("/ship ") or text == "/ship":
                args = text[len("/ship"):].strip()
                handle_ship(token, chat_id, args)
            elif text.startswith("/start"):
                send(token, chat_id,
                     "Agentic Ship Kit ready!\n\n"
                     "Send /help to see available commands.\n"
                     "Send /projects to see registered projects.")
            # else: ignore unknown commands

if __name__ == "__main__":
    try:
        main()
    finally:
        if os.path.exists(POLLER_LOCK):
            try:
                os.remove(POLLER_LOCK)
            except OSError:
                pass
