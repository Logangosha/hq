---
name: setup-hq
description: Set up a fresh copy of HQ for a new user — their GitHub owner, their domain repos, the workflow, labels, Claude app and token — then prove it with a test Work Item. Use when someone has just copied HQ, says "set up HQ", or check-setup.sh reports problems.
---

# Set up HQ

Get a new user from "just copied HQ" to "a Work Item ran by itself". One step at a
time, short replies. They may be new to GitHub — give exact commands, never "configure X".

## 1. See where they are

```bash
bash scripts/check-setup.sh
```

Start from the first ❌. If tools are missing (git, gh, gh login), give them the fix and
stop until it passes — nothing else works without `gh`.

## 2. Owner and domains

- **Owner:** don't ask. Use `gh api user --jq .login` and state it in one line.
- **Domains:** ask what kinds of work they want HQ to handle, in their words. Turn each
  answer into a row: a short repo name and one line of "What belongs here".
- Always offer `hq-test-sandbox` too — fake content, safe to break, for trying things.

Rewrite `registry/domains.md`: set the owner, replace the table rows with theirs, status
`active` for repos that will exist after step 3. Keep the rest of the file.

## 3. Repos *(ask first)*

List the repos that don't exist yet and ask once for all of them. On yes:

```bash
gh repo create <owner>/<repo> --private --add-readme -d "<What belongs here>"
```

For `hq-test-sandbox`, add a couple of small fake files (e.g. `docs/menu.md`) so a test
Work Item has something to change.

## 4. Workflow and labels

For each domain:

```bash
bash scripts/enable-agents.sh <owner>/<repo>
```

## 5. Claude app and token *(they do these — credentials are theirs)*

Give one at a time, wait for "done" between them.

1. **App:** open https://github.com/apps/claude → Install → **All repositories**.
2. **Token:** needs Claude Code in a terminal. In a plain PowerShell / Terminal window
   (not inside the Claude desktop app — it won't see a fresh install):
   `claude setup-token`, then copy the token it prints.
3. **Secret, per domain.** Strip whitespace — a terminal that wraps the long token
   inserts line breaks when copying, and the run then fails with a bad token.
   - Windows PowerShell:
     `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo> --body ((Get-Clipboard -Raw) -replace '\s','')`
   - Mac: `pbpaste | tr -d '[:space:]' | gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo>`

   Give the command once per domain, with the repo filled in.

If `claude` isn't found after installing, its folder isn't on PATH yet — open a new
terminal, or on Windows add `%USERPROFILE%\.local\bin` to the user Path.

## 6. Check, save, prove

1. `bash scripts/check-setup.sh` — must end "All set."
2. Commit `registry/domains.md` and push.
3. Create a test Work Item with the `new-work-item` skill in `hq-test-sandbox`, and give
   them the link. The first comment should appear within a couple of minutes. If the run
   fails, read it: `gh run list --repo <owner>/hq-test-sandbox` then
   `gh run view <id> --log-failed`.

Done when a test Work Item reaches `stage:review` by itself.
