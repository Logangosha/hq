---
name: open-hq
description: Open the review dashboard in the browser, starting it first if it isn't running. Use when the user says "open the dashboard", "open hq", or "/open-hq".
---

# /open-hq

Run from the HQ root:

```bash
python dashboard/ctl.py start
```

This starts the dashboard only if nothing is listening yet, and always opens it in the
browser afterward. Relay its one line of output verbatim. Never ask the user for a port
or process id — `ctl.py` finds whatever's listening on the dashboard's port itself
(`$env:PORT`/`PORT`, else 8765) and works the same from PowerShell, Git Bash, or any
shell.
