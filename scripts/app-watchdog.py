"""Backstop for a review app instance whose dashboard or Claude session died without
clicking Stop (R8). Runs detached from the dashboard process, since that's the thing
that may have died, so it has to watch from outside.

Polls a heartbeat file: the dashboard touches it while the review is open (Start,
Restart, and a ping every 60s while the tab stays open). If the file goes stale past
the timeout, or the app process is already gone, or the file was deleted (a normal
Stop), this exits.

Usage: python scripts/app-watchdog.py <pid> <heartbeat-file> <timeout-seconds>
"""
import os
import signal
import subprocess
import sys
import time

POLL = 15


def alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def kill(pid):
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(pid)], check=False)
    else:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass


def main():
    pid, heartbeat, timeout = int(sys.argv[1]), sys.argv[2], float(sys.argv[3])
    while True:
        time.sleep(POLL)
        if not os.path.exists(heartbeat):
            return  # stopped normally; nothing to do
        if not alive(pid):
            return
        if time.time() - os.path.getmtime(heartbeat) > timeout:
            kill(pid)
            return


if __name__ == "__main__":
    main()
