---
name: start-hq
description: Start the review dashboard. Use when the user says "start the dashboard", "start hq", or "/start-hq".
---

# /start-hq

Run from the HQ root:

```bash
python dashboard/ctl.py start
```

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
