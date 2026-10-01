# Proposing a Work Item

The rules for turning an idea into a proposal. Shared by the `new-work-item` skill and the
`propose` agent — edit them here only. Nothing is created until a clear yes.

## Check the repo is a domain

**Check it's a domain before anything else.** The owner is whoever owns this copy of HQ.
A repo is a domain only if it has the Work Item workflow — otherwise no agent would run:

```bash
gh api repos/<owner>/<repo>/contents/.github/workflows/work-item.yml --silent
```

- **Repo doesn't exist** → stop. One line: it doesn't exist; `/add-domain <repo>` creates
  and sets it up.
- **Exists, no workflow** → stop. One line: it isn't set up yet; `/add-domain <repo>`.
- `hq` itself is the exception — system work is tracked there without the workflow.

The create script refuses both cases too (exit 2 and 3), so nothing half-made is ever left behind.

## Write the goal

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

## Small, normal or big

Judge it yourself against `orchestration/lifecycle.md`'s small criteria: a quick fix or
simple change, 1–3 files in one repo, an obvious fix. Anything touching agents, skills,
the runner, secrets or real data is always normal.

**Normal** — one Work Item in one repo: the default for anything that isn't small.

**Big** — it can only be delivered as several Work Items that depend on each other (e.g. a
new multi-part feature, or ordered work across repos). One agent file is normal, not big.

When unsure between normal and big, choose normal. **Never ask the user to choose** —
decide, and state your guess in the proposal (see Propose).

## Propose

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
