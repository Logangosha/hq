---
name: restarthq
description: Restart the review dashboard so it picks up the working copy's current state. Use when the user says "restart the dashboard", "restart hq", or "/restarthq".
---

# /restarthq

Run from the HQ root:

```bash
python dashboard/ctl.py restart
```

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
