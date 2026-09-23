"""Start, stop, or restart the review dashboard (dashboard/server.py) without the user
hunting for its port or process id themselves.

Usage: python dashboard/ctl.py <start|stop|restart> [branch]
"""
import os
import re
import subprocess
import sys
import tempfile
import time
import webbrowser

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER = os.path.join(HQ, "dashboard", "server.py")
PORT = int(os.environ.get("PORT", "8765"))
# Outside the repo: server.py reads its content once at startup (see its hq_version()
# docstring), so this is the only record of which branch a running process is actually
# serving. Keeping it out of HQ's own working copy means it never shows up in dirty().
SERVED_BRANCH_FILE = os.path.join(tempfile.gettempdir(), f"hq-dashboard-branch-{PORT}")
# Outside the repo, same reasoning: where the dashboard's own Restart HQ button reads
# ctl.py restart's outcome line from, once the detached child exits.
RESTART_OUTCOME_FILE = os.path.join(tempfile.gettempdir(), f"hq-dashboard-restart-{PORT}.txt")

# ctl.py has no console of its own once detached; without this, Windows pops a fresh
# console window for every git call this makes.
NO_WINDOW = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}


def find_pid(port):
    """PID of whatever's listening on port, or None."""
    if os.name == "nt":
        out = subprocess.run(["netstat", "-ano"], capture_output=True, text=True).stdout
        for line in out.splitlines():
            fields = line.split()
            if len(fields) >= 5 and fields[0] == "TCP" and fields[3] == "LISTENING":
                addr = fields[1]
                if addr.rsplit(":", 1)[-1] == str(port):
                    return int(fields[-1])
        return None
    inode = None
    for path in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(path, encoding="utf-8") as fh:
                lines = fh.readlines()[1:]
        except FileNotFoundError:
            continue
        for line in lines:
            fields = line.split()
            local, state = fields[1], fields[3]
            local_port = int(local.rsplit(":", 1)[-1], 16)
            if local_port == port and state == "0A":  # TCP_LISTEN
                inode = fields[9]
                break
        if inode:
            break
    if not inode:
        return None
    for pid_dir in os.listdir("/proc"):
        if not pid_dir.isdigit():
            continue
        fd_dir = f"/proc/{pid_dir}/fd"
        try:
            fds = os.listdir(fd_dir)
        except (FileNotFoundError, PermissionError):
            continue
        for fd in fds:
            try:
                target = os.readlink(f"{fd_dir}/{fd}")
            except OSError:
                continue
            if target == f"socket:[{inode}]":
                return int(pid_dir)
    return None


def dirty():
    """True if the HQ working copy has uncommitted changes."""
    out = subprocess.run(["git", "status", "--porcelain"], cwd=HQ,
                          capture_output=True, text=True).stdout
    return bool(out.strip())


def current_branch():
    return subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=HQ,
                           capture_output=True, text=True).stdout.strip()


def served_branch():
    """Branch the currently-running server process was launched against, or None if
    unknown (never launched by ctl.py, or the marker's gone)."""
    try:
        with open(SERVED_BRANCH_FILE, encoding="utf-8") as fh:
            return fh.read().strip()
    except FileNotFoundError:
        return None


def _record_served_branch(branch):
    with open(SERVED_BRANCH_FILE, "w", encoding="utf-8") as fh:
        fh.write(branch)


def ensure_branch(branch):
    """Make `branch` the one checked out in the HQ working copy.

    Returns a one-line reason and touches nothing if that isn't possible right now,
    else None.
    """
    if dirty():
        return "Uncommitted changes in the HQ working copy — commit or stash them first."
    if current_branch() == branch:
        return None
    result = subprocess.run(["git", "checkout", branch], cwd=HQ,
                             capture_output=True, text=True)
    if result.returncode != 0:
        return result.stderr.strip().splitlines()[-1] if result.stderr.strip() else \
            f"Couldn't check out {branch}."
    return None


def stop():
    pid = find_pid(PORT)
    if pid is None:
        print(f"Nothing is listening on port {PORT}.")
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
    else:
        os.kill(pid, 15)  # SIGTERM
    print(f"Stopped the dashboard (pid {pid}) on port {PORT}.")


def update():
    """Fast-forward-only pull of the current branch from its tracked remote, if that's
    safe. Returns (ok, detail): the short sha now checked out if ok, else why the
    checkout was left alone."""
    kwargs = {"cwd": HQ, "capture_output": True, "text": True, "encoding": "utf-8", **NO_WINDOW}
    if subprocess.run(["git", "status", "--porcelain"], **kwargs).stdout.strip():
        return False, "local edits present"
    if subprocess.run(["git", "fetch"], **kwargs).returncode != 0:
        return False, "fetch failed"
    upstream = subprocess.run(["git", "rev-parse", "@{u}"], **kwargs)
    if upstream.returncode != 0:
        return False, "no tracked remote"
    head = subprocess.run(["git", "rev-parse", "HEAD"], **kwargs).stdout.strip()
    base = subprocess.run(["git", "merge-base", "HEAD", "@{u}"], **kwargs).stdout.strip()
    if base != head:
        return False, "diverged from remote"
    subprocess.run(["git", "merge", "--ff-only", "@{u}"], **kwargs)
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], **kwargs).stdout.strip()
    return True, sha


def _launch():
    if find_pid(PORT) is not None:
        print(f"Already running on port {PORT}.")
    else:
        ok, detail = update()
        kwargs = {"cwd": HQ, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
        if os.name == "nt":
            kwargs["creationflags"] = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            kwargs["start_new_session"] = True
        subprocess.Popen([sys.executable, SERVER], **kwargs)
        for _ in range(20):
            if find_pid(PORT) is not None:
                break
            time.sleep(0.25)
        _record_served_branch(current_branch())
        if ok:
            print(f"Started the dashboard on port {PORT} (now at {detail}).")
        else:
            print(f"Started the dashboard on port {PORT} (couldn't update: {detail}).")
    if not os.environ.get("HQ_NO_BROWSER"):
        webbrowser.open(f"http://localhost:{PORT}")


def _stop_and_wait():
    if find_pid(PORT) is not None:
        stop()
        for _ in range(20):
            if find_pid(PORT) is None:
                break
            time.sleep(0.25)


def start(branch=None):
    target = branch or "main"
    reason = ensure_branch(target)
    if reason:
        print(reason)
        return
    if find_pid(PORT) is not None and served_branch() != target:
        # The running server was launched against a different branch than the one
        # ensure_branch just checked out (explicitly named, or left over from an
        # earlier explicit start). server.py reads its content once at startup, so
        # checking the branch out on disk alone never reaches what's served — only a
        # relaunch does.
        _stop_and_wait()
    _launch()


def restart(branch=None):
    reason = ensure_branch(branch or "main")
    if reason:
        print(reason)
        return
    _stop_and_wait()
    _launch()


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action not in ("start", "stop", "restart"):
        print("Usage: python dashboard/ctl.py <start|stop|restart> [branch]", file=sys.stderr)
        sys.exit(1)
    branch_arg = sys.argv[2] if len(sys.argv) > 2 else None
    if action == "stop":
        stop()
    else:
        {"start": start, "restart": restart}[action](branch_arg)
