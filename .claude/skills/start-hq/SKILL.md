---
name: start-hq
description: Start the review dashboard. Use when the user says "start the dashboard", "start hq", or "/start-hq".
---

# /start-hq

Run from the HQ root:

```bash
python dashboard/ctl.py start
```

This serves `main` of the HQ working copy, checking it out first if some other branch is
checked out. If the working copy has uncommitted changes, it stops instead of touching
anything and prints why. Only pass a branch (`python dashboard/ctl.py start <branch>`)
when the user explicitly names one — never as the default.

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
