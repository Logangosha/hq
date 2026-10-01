---
name: new-work-item
description: Turn a plain request into a Work Item Issue in the right repo. Use whenever the user asks for something to be done, built, fixed, changed or written — "I want X done in Y", "we need to fix Z", "can you add W" — including when they don't name a repo. Not for questions, and not when they want it done right now in this session.
---

# New Work Item

The user says what they want. You show a proposal, and create the Issue only after their yes.

## 1. Work out the repo

Read `registry/routing.md` and follow it. **Don't ask which repo** — decide; the repo goes
in the proposal (step 3). A wrong route is undone with `gh issue transfer`.

Stop only if no domain fits. Then say what's missing and propose one; creating a repo
needs the user's yes.

**Check it's a domain before anything else** — the rules are in `orchestration/proposing.md`, "Check the repo is a domain".

## 2. Write the goal

Follow `orchestration/proposing.md`, "Write the goal".

## 2b. Small, normal or big

Follow `orchestration/proposing.md`, "Small, normal or big".

## 3. Propose

Follow `orchestration/proposing.md`, "Propose" — including the blueprint for a big request.

## 4. On yes, create it

Runs only after the user's yes to the latest proposal.

**Small:**

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Title" "Current state" "Desired state" --small
```

It starts at `stage:scope` instead of `stage:requirements`.

**Normal:**

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Title" "Current state" "Desired state"
```

**Big:** create the parent, then each part in blueprint order.

The parent's home is the parts' repo if they all share one, otherwise `hq`.

```bash
bash scripts/parent.sh create <owner>/<repo> "Title" "Outcome"
```

Then per part, in order:

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Part title" "Current state" "Desired state" \
  [--small] [--blocked-by <owner>/<repo>#<n> ...]
bash scripts/parent.sh add <owner>/<repo>#<parent-n> <owner>/<repo>#<part-n>
```

Use `--small` for a small part. Give a part one `--blocked-by` per part it waits on,
resolved to the Issue number just created for that part; a part that waits on nothing
gets no `--blocked-by` and starts at `stage:requirements` (`stage:scope` if small) —
don't add labels by hand and don't change a part's starting stage.

Never add a label to the parent — no agent stage ever runs on it.

**If any step fails, stop immediately.** The reply names every Issue already created
(parent and parts), so nothing already made is lost track of.

Long or formatted goals: pass `-` as the third argument and pipe the body in.

The script handles the `Work Item:` prefix and the labels. Don't add labels by hand.

If this request depends on other Work Items finishing first, resolve each to
`owner/repo#number` the same way you resolve the target repo, and repeat `--blocked-by`
once per dependency — they can be in any repo:

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Title" "Current state" "Desired state" \
  --blocked-by <owner>/<repo>#<n> --blocked-by <owner>/<repo>#<m>
```

A blocked Work Item starts parked (`waiting:work`, no stage) and only begins Requirements
(or Scope, if small) once every blocker's PR has merged. If a blocker is closed without
merging, it goes to the user to decide.

## 5. Reply

One line, then the link. Nothing else — no recap of what you just wrote, they can open it.

> Bakery docs → `bakery-site`. #12

For a **big** request, the reply is the parent's link, same shape:

> Invoicing → 3 parts in `billing-api`, `billing-web`. #120

## 6. Changing a parent

Only for a parent created by this skill (`parent.sh create`). It isn't a Work Item, so
its part list can be edited over time.

**Add a part.** Propose it — same fields as the blueprint, plus where it goes (usually
last) — ending **Proceed?**. On yes, create it as in step 4's Big path, then place it:

```bash
bash scripts/parent.sh add <owner>/<repo>#<parent-n> <owner>/<repo>#<new-part-n>
bash scripts/parent.sh move <owner>/<repo>#<parent-n> <owner>/<repo>#<new-part-n> --after <owner>/<repo>#<prior-part-n>
```

(skip `move` if the part belongs last — `add` already appends it.)

**Reorder.** Show the new order, ending **Proceed?**. On yes, `parent.sh move` each part
that changed position:

```bash
bash scripts/parent.sh move <owner>/<repo>#<parent-n> <owner>/<repo>#<part-n> --after <owner>/<repo>#<other-n>
```

**Drop.** Name the part, ending **Proceed?**. On yes:

```bash
bash scripts/drop-work-item.sh <repo> <part-n>
bash scripts/parent.sh remove <owner>/<repo>#<parent-n> <owner>/<repo>#<part-n>
bash scripts/parent.sh close-if-done <owner>/<repo>#<parent-n>
```

Reordering doesn't rewire `--blocked-by` — if a move would break a dependency, say so in
the proposal instead of changing blockers.

Progress ("N of M done") is GitHub's own sub-issue count on the parent — nothing to
maintain by hand.

## If they ask for several things

One proposal per request, numbered, in one message, ending with a single **Proceed?**. The
user can say yes, or correct or drop any one of them — each redraws just that proposal.
Create only after the yes, then one line listing the links. Work spanning two repos is two
Work Items — say which depends on which.
