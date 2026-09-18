---
name: repos
description: Show all of the user's GitHub repos — which are domains, which are cloned on this computer, which aren't — so they can pick ones to add. Use when the user asks "show my repos", "what repos do I have", "what could I add", "what's local", or "/repos".
---

# Repos

```bash
bash scripts/list-repos.sh
```

Each line is `repo<TAB>domain<TAB>local<TAB>private<TAB>description`. Show one table and
nothing else. Domains first, then the rest by name:

| Repo | Domain | Local | What it is |
|---|---|---|---|
| `<repo>` 🔒 if private | ✅ or blank | the folder path, or blank | `<description>`, or *no description* |

Then one line: `/add-domain <repo>` adds any of them.
