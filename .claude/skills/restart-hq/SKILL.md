---
name: restart-hq
description: Restart the review dashboard so it picks up the working copy's current state. Use when the user says "restart the dashboard", "restart hq", or "/restart-hq".
---

# /restart-hq

Run from the HQ root:

```bash
python dashboard/ctl.py restart
```

This serves `main` of the HQ working copy, checking it out first if some other branch is
checked out, regardless of what the dashboard had been serving before. If the working
copy has uncommitted changes, it stops instead of touching anything (the running
dashboard keeps running as-is) and prints why. Only pass a branch
(`python dashboard/ctl.py restart <branch>`) when the user explicitly names one — never
as the default.

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
