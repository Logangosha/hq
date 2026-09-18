---
name: add-domain
description: Add a new domain repo to HQ so Work Items can run in it — registry row, repo (created if missing, after asking), workflow, labels and the Claude token. Use when the user says "add a repo", "add a domain", "start using HQ in <repo>", or a Work Item is wanted in a repo not in registry/domains.md.
---

# Add a domain

The user names the repo and says what it's for. You do everything else. They never run a
command — the only thing they do by hand is the token, because it's a credential.

## 1. What and where

- **Owner:** from `registry/domains.md`.
- **Repo name and what belongs there:** from the user. If they didn't say what belongs
  there, work it out from the repo's README and state it in one line.

## 2. The repo *(ask first if it doesn't exist)*

```bash
gh repo view <owner>/<repo>
```

Missing → ask once, then `gh repo create <owner>/<repo> --private --add-readme -d "<what belongs here>"`.

## 3. Registry

Add a row to the table in `registry/domains.md`, status `active`.

## 4. Workflow and labels

```bash
bash scripts/enable-agents.sh <owner>/<repo>
```

## 5. Token *(the user does this)*

Check first — it may already be there:

```bash
gh secret list --repo <owner>/<repo>
```

If `CLAUDE_CODE_OAUTH_TOKEN` is missing, walk them through step 5 of
`.claude/skills/setup-hq/SKILL.md` (the web page route), with the repo filled in. Wait for
"done", then check again.

## 6. Save and confirm

Commit and push `registry/domains.md`. Reply in one line: the repo is ready, and they can
now say `/new-work-item … in <repo>`.
