---
name: add-domain
description: Add a new domain repo to HQ so Work Items can run in it — repo (created if missing, after asking), description, workflow, labels and the Claude token. Use when the user says "add a repo", "add a domain", "start using HQ in <repo>", or a Work Item is wanted in a repo that has no Work Item workflow yet.
---

# Add a domain

The user names the repo and says what it's for. You do everything else. They never run a
command — the only thing they do by hand is the token, because it's a credential.

## 1. What and where

- **Owner:** whoever owns this copy of HQ — `gh repo view --json owner --jq .owner.login`.
- **Repo name and what belongs there:** from the user. If they didn't say what belongs
  there, work it out from the repo's README and state it in one line.

## 2. The repo *(ask first if it doesn't exist)*

```bash
gh repo view <owner>/<repo>
```

Missing → ask once, then `gh repo create <owner>/<repo> --private --add-readme -d "<what belongs here>"`.

## 3. Description

The repo's GitHub description is how HQ knows what belongs there — there's no list in HQ.
Set it if it's empty or doesn't say:

```bash
gh repo edit <owner>/<repo> --description "<what belongs here>"
```

## 4. Workflow and labels

```bash
bash scripts/enable-agents.sh <owner>/<repo>
```

## 5. Token *(the user does this)*

Check first — it may already be there:

```bash
gh secret list --repo <owner>/<repo>
```

If `CLAUDE_CODE_OAUTH_TOKEN` is missing, walk them through step 4 of
`.claude/skills/setup-hq/SKILL.md` (the web page route), with the repo filled in. Wait for
"done", then check again.

## 6. Confirm

One line: the repo is ready, and they can now say `/new-work-item … in <repo>`.
