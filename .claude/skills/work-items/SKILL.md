---
name: work-items
description: Show every domain as a folder with its open Work Items nested beneath it, each with its stage. Use when the user asks "show my work items", "work item tree", "what's the status across domains", or "/work-items".
---

# Work Items

```bash
bash scripts/list-work-items.sh
```

Output is grouped by domain: a `DOMAIN<TAB><owner>/<repo>` line, followed by that domain's
open Work Items as `<repo><TAB><number><TAB><title><TAB><stage><TAB><url><TAB><waiting>` lines
(`<waiting>` is any `waiting:` labels, usually empty) (none if
the domain has no open Work Items).

Render one combined tree, all domains together, in this shape:

```
### <owner>/<repo>
- [#<number> <title>](<url>) — <stage>
```

A domain with no open Work Items still gets its heading, followed by:
*(no open Work Items)*

Show nothing else — no per-repo commentary, no summary line.
