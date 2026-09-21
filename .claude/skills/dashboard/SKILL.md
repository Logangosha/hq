---
name: dashboard
description: Start, stop, or restart the review dashboard by name. Use when the user says "start the dashboard", "stop the dashboard", "restart the dashboard", or "/dashboard".
---

# Dashboard

Run from the HQ root, from the user's words (start/stop/restart):

```bash
python dashboard/ctl.py <start|stop|restart>
```

Relay its one line of output verbatim. Never ask the user for a port or process id —
`ctl.py` finds whatever's listening on the dashboard's port itself (`$env:PORT`/`PORT`,
else 8765) and works the same from PowerShell, Git Bash, or any shell.
