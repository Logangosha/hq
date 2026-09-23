---
name: review
description: Let the user look at a finished Work Item on their own computer, then approve (merge) or reject it (back to Requirements with their comments). Use when a Work Item is at stage:review and the user says "review <repo>#<n>", "let me see it", "show me the app", or "/review".
---

# Review

Stage 6. The user looks; you do every git and GitHub step. They never check out a branch.

## 1. Which Work Item

`<repo>#<n>` from the user. No number → list the domain's `stage:review` Issues and ask
which. It must be a domain (same check as `new-work-item`) and at `stage:review`; if not,
say where it is in one line and stop.

## 2. Check out

```bash
bash scripts/review-checkout.sh <repo> <n>
```

| Exit | Say |
|---|---|
| 2 | No open PR yet — the builder hasn't opened one |
| 3 | The folder has unsaved edits (list them). Don't touch them; ask the user to save or discard them first |

Keep the printed `pr`, `default`, `path` and `launch` for the steps below. `path` is
never HQ's own folder — HQ Work Items get a review copy under `.hq-reviews/` beside HQ,
so a review can't move the work you're doing here onto another branch.

## 3. Show it

- **`launch` is a file:** read it, run the first configuration's `runtimeExecutable` +
  `runtimeArgs` from `path` as a background command, then open its `url` (or
  `http://localhost:<port>`) in the browser pane.
- **No launch file:** work out how to run it from the repo (README, `package.json`). If
  nothing runs — docs, data — open the PR's **Files changed** page instead.

Then, beside it, one short block:
- **What changed:** the PR title and one line.
- **QA:** the latest QA comment's table (`## 5. QA`, or a re-run such as
  `## 5b. QA (re-run)`), trimmed to check + result.
- **After merge** — only if that comment has a `### After merge` heading: show its list
  verbatim and tell the user to do these after merging. Leave this bullet out otherwise.
- **Try this:** one or two things to click, taken from the requirements.
- **⚠️ Changes `.claude/`** — only if the PR does (`gh pr diff <pr> --name-only`). List
  those files and say what each change does in one line: they change how agents and
  Claude behave, so they need a closer look than the app.

Ask: **approve**, or what's wrong?

## 4. Their answer

**Approve:**
```bash
gh pr merge <pr> --repo <owner>/<repo> --squash --delete-branch
```
The PR's `Closes #<n>` closes the Issue. That's Done.

**Anything else is a rejection.** Their words go on the Issue verbatim, then the label
goes back — which starts the requirements agent:
```bash
gh issue comment <n> --repo <owner>/<repo> --body "## 6. Review — user ❌

<their words>"
gh issue edit <n> --repo <owner>/<repo> --remove-label stage:review --add-label stage:requirements
```
Leave the PR open; the rebuild reuses it.

## 5. Clean up — always, even if they stop half-way

Stop the app you started. Then put their copy back:
```bash
git -C "<path>" checkout <default> && git -C "<path>" pull --quiet
```

One line: what happened, and the Issue link.
