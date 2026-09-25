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

**Check it's a domain before anything else.** The owner is whoever owns this copy of HQ.
A repo is a domain only if it has the Work Item workflow — otherwise no agent would run:

```bash
gh api repos/<owner>/<repo>/contents/.github/workflows/work-item.yml --silent
```

- **Repo doesn't exist** → stop. One line: it doesn't exist; `/add-domain <repo>` creates
  and sets it up.
- **Exists, no workflow** → stop. One line: it isn't set up yet; `/add-domain <repo>`.
- `hq` itself is the exception — system work is tracked there without the workflow.

The script refuses both cases too (exit 2 and 3), so nothing half-made is ever left behind.

## 2. Write the goal

Their sentence is not the goal. The goal is two halves, and you work them out by **reading
the repo** — never from the request alone:

- **Current state** — what is true now, naming real files. `docs/staff.md` still lists
  B. Miller, not "the staff page is wrong".
- **Desired state** — what must be true instead. The outcome, not the steps.

Put any concrete details the user gave you (names, numbers, addresses, prices) in the
current state verbatim. If they didn't give you a detail the work needs, say so in the
goal rather than inventing it — stage 1 will pick it up.

**Write no requirements, no checks, no plan.** Those are the agents' work and arrive as
comments. If you catch yourself planning, stop.

## 2b. Small, normal or big

Judge it yourself against `orchestration/lifecycle.md`'s small criteria: a quick fix or
simple change, 1–3 files in one repo, an obvious fix. Anything touching agents, skills,
the runner, secrets or real data is always normal.

**Normal** — one Work Item in one repo: the default for anything that isn't small.

**Big** — it can only be delivered as several Work Items that depend on each other (e.g. a
new multi-part feature, or ordered work across repos). One agent file is normal, not big.

When unsure between normal and big, choose normal. **Never ask the user to choose** —
decide, and state your guess in the proposal (step 3).

## 3. Propose

Before creating anything, show:

- **Repo**
- **Size** — small / normal / big, with a one-line reason
- **Title**
- **Goal** — current state and desired state

End with **Proceed?**. Nothing is created yet.

> **Repo:** `bakery-site`
> **Size:** small — one file, wording only
> **Title:** Fix staff page
> **Current state:** `docs/staff.md` still lists B. Miller.
> **Desired state:** `docs/staff.md` lists the current staff.
>
> Proceed?

A correction — a different size, repo, title or goal — produces an updated proposal and a
new **Proceed?**. A correction is never taken as a yes; only a clear yes moves on to step 4.

### Big: the blueprint

For a **big** request, the proposal above becomes a **blueprint** instead of a single
goal. First, ask clarifying questions — but only if a part's goal would otherwise need
an invented detail; otherwise skip straight to the blueprint.

List the parts in delivery order. Each part has a title, a repo, a size (small or
normal — never big), a one-line goal, and what it waits on (none, or earlier part
numbers only).

> **Blueprint: Invoicing**
>
> | # | Title | Repo | Size | Goal | Waits on |
> |---|---|---|---|---|---|
> | 1 | Add invoice model | `billing-api` | normal | Store an invoice per order | none |
> | 2 | Invoice PDF export | `billing-api` | small | Render an invoice as PDF | 1 |
> | 3 | Invoice tab in dashboard | `billing-web` | normal | Show invoices on the account page | 1 |
>
> Proceed?

Ends with **Proceed?**, same as any proposal. A correction redraws the **whole**
blueprint with a new **Proceed?** — never a partial patch. Nothing is created before a
clear yes.

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
