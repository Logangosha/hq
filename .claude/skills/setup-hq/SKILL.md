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
- **Domains:** ask what kinds of work they want HQ to handle, in their words, and which
  repos (existing or new) that work lives in. A fresh copy of HQ has none.
- **A place to test:** suggest one throwaway private repo of their own naming for the test
  run in step 6, so the first Work Item doesn't touch anything real. Optional.

## 3. Add each domain

Run the `add-domain` skill for each repo, steps 1–4 (it asks before creating a repo, and
sets the repo's description to what belongs there). If they chose a test repo, add a
couple of small fake files to it so a test Work Item has something to change.

## 4. Claude app and token *(they do these — credentials are theirs)*

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

## 5. Check and prove

1. Run the `check-setup` skill — it must end "All set."
2. Create a small test Work Item with the `new-work-item` skill — in their test repo if
   they made one — and give them the link. The first comment should appear within a
   couple of minutes. If the run fails, read it: `gh run list --repo <owner>/<repo>` then
   `gh run view <id> --log-failed`.

Done when a test Work Item reaches `stage:review` by itself.
