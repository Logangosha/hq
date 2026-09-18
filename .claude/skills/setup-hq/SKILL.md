---
name: setup-hq
description: Set up a fresh copy of HQ for a new user — their GitHub owner, their domain repos, the workflow, labels, Claude app and token — then prove it with a test Work Item. Use when someone has just copied HQ, says "set up HQ", or check-setup.sh reports problems.
---

# Set up HQ

Get a new user from "just copied HQ" to "a Work Item ran by itself". One step at a
time, short replies. They may be new to GitHub — give exact commands, never "configure X".

## 1. See where they are

Run `bash scripts/check-setup.sh` yourself — the user never runs commands.

Start from the first ❌. If tools are missing (git, gh, gh login), give them the fix and
stop until it passes — nothing else works without `gh`.

## 2. Owner and domains

- **Owner:** nothing to set — it's whoever owns this copy of HQ. State it in one line
  (`gh repo view --json owner --jq .owner.login`). If it isn't them, they cloned someone
  else's HQ instead of copying it: send them to README → How to use, step 2.
- **Domains:** ask what kinds of work they want HQ to handle, in their words. Turn each
  answer into a row: a short repo name and one line of "What belongs here".
- `hq-test-sandbox` is already in the registry — the starter domain every copy gets.
  Keep it unless they say no.

Add their rows to `registry/domains.md`, status `active` for repos that will exist after
step 3.

## 3. Repos *(ask first)*

List the repos that don't exist yet and ask once for all of them. On yes:

```bash
gh repo create <owner>/<repo> --private --add-readme -d "<What belongs here>"
```

For `hq-test-sandbox`, add a couple of small fake files (e.g. `docs/menu.md`) so a test
Work Item has something to change.

## 4. Workflow and labels

For each domain, use the `add-domain` skill's step 4 (you run it).

## 5. Claude app and token *(they do these — credentials are theirs)*

Give one at a time, wait for "done" between them.

1. **App:** open https://github.com/apps/claude → Install → **All repositories**.
2. **Token:** needs Claude Code in a terminal. In a plain PowerShell / Terminal window
   (not inside the Claude desktop app — it won't see a fresh install):
   `claude setup-token`, then copy the token it prints.
3. **Secret, per domain — on the GitHub website**, so they type no commands. Send them
   `https://github.com/<owner>/<repo>/settings/secrets/actions/new` (filled in), then:
   - **Name:** `CLAUDE_CODE_OAUTH_TOKEN`
   - **Secret:** paste the token. It must be **one line** starting `sk-ant-oat01`. A
     terminal that wraps the long token inserts line breaks when copying — if the box
     shows more than one line, delete the breaks.
   - **Add secret.**

   If a run later fails in ~1 turn with $0 cost, the token has a stray break. Terminal
   fallback that strips it — Windows PowerShell:
   `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo> --body ((Get-Clipboard -Raw) -replace '\s','')`
   — Mac: `pbpaste | tr -d '[:space:]' | gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo>`

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
