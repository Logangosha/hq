"""Start, stop, or restart the review dashboard (dashboard/server.py) without the user
hunting for its port or process id themselves.

Usage: python dashboard/ctl.py <start|stop|restart>
"""
import os
import re
import subprocess
import sys
import time
import webbrowser

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVER = os.path.join(HQ, "dashboard", "server.py")
PORT = int(os.environ.get("PORT", "8765"))


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


def start():
    if find_pid(PORT) is not None:
        print(f"Already running on port {PORT}.")
    else:
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
        print(f"Started the dashboard on port {PORT}.")
    webbrowser.open(f"http://localhost:{PORT}")


def restart():
    if find_pid(PORT) is not None:
        stop()
        for _ in range(20):
            if find_pid(PORT) is None:
                break
            time.sleep(0.25)
    start()


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action not in ("start", "stop", "restart"):
        print("Usage: python dashboard/ctl.py <start|stop|restart>", file=sys.stderr)
        sys.exit(1)
    {"start": start, "stop": stop, "restart": restart}[action]()
