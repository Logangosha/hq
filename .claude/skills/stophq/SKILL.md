---
name: stophq
description: Stop the review dashboard. Use when the user says "stop the dashboard", "stop hq", or "/stophq".
---

# /stophq

Run from the HQ root:

```bash
python dashboard/ctl.py stop
```

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
