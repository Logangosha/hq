---
name: check-setup
description: Check whether HQ is fully set up — tools, HQ repo, every domain's repo, workflow, labels and Claude token — and fix what can be fixed. Use when the user asks "is everything set up?", "check my setup", "why isn't it running?", or after any setup change.
---

# Check setup

The user never runs this themselves. You run it, read it, and fix what you can.

```bash
bash scripts/check-setup.sh
```

## Reply

- **All ✅:** one line — "All set", plus the reminder the script prints about the Claude
  GitHub App, which it can't check.
- **Any ❌:** one line per problem, in plain words. Then fix, one at a time:

| Problem | Who fixes it |
|---|---|
| Workflow or labels missing | You — `bash scripts/enable-agents.sh <owner>/<repo>`, then re-check |
| Repo missing | You, after asking — see the `add-domain` skill |
| No owner or no domains | You — run the `setup-hq` skill |
| HQ not public | The user — GitHub → `hq` → Settings → Change visibility |
| Token secret missing | The user — step 5 of `.claude/skills/setup-hq/SKILL.md` |
| git / gh / gh login missing | The user — give the install link or `gh auth login` |

Re-run the check after each fix, and finish on "All set".

**If everything is ✅ but Work Items still don't run,** read the latest run:
`gh run list --repo <owner>/<repo> --limit 3`, then `gh run view <id> --log-failed`.
Known causes: an empty or whitespace-broken token (`is_error` after ~1 turn, $0 cost), the
Claude app not installed on that repo, or a `waiting:` label on the Issue.
