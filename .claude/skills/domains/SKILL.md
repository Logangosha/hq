---
name: domains
description: Show the user's list of domains — the repos HQ can send Work Items to — with what belongs in each. Use when the user asks "what are my domains", "list my repos", "where can I send work", or "/domains".
---

# Domains

HQ keeps no list (it's public — see `registry/domains.md`). Build it live:

```bash
bash scripts/list-domains.sh
```

Each line is `repo<TAB>description`. Show one table and nothing else:

| Domain | What belongs here |
|---|---|
| `<repo>` | `<description>` |

Then one line with the GitHub link that shows the same list, for their phone:
`https://github.com/<owner>?tab=repositories&q=topic%3Ahq-domain` (owner = whoever owns
this copy of HQ).

**No domains yet** → one line: none yet, and `/add-domain <repo>` adds the first.
