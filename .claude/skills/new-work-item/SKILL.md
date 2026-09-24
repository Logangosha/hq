---
name: new-work-item
description: Turn a plain request into a Work Item Issue in the right repo. Use whenever the user asks for something to be done, built, fixed, changed or written — "I want X done in Y", "we need to fix Z", "can you add W" — including when they don't name a repo. Not for questions, and not when they want it done right now in this session.
---

# New Work Item

The user says what they want. You produce one Issue and one line of reply.

## 1. Work out the repo

Read `registry/routing.md` and follow it. **Don't ask which repo** — decide, and say which
you picked if it wasn't obvious. A wrong route is undone with `gh issue transfer`.

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

## 2b. Small or normal

Judge it yourself against `orchestration/lifecycle.md`'s small criteria: a quick fix or
simple change, 1–3 files in one repo, an obvious fix. Anything touching agents, skills,
the runner, secrets or real data is always normal. When unsure, it's normal. **Never ask
the user to choose** — decide, and state your guess in the reply (step 4).

## 3. Create it

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Title" "Current state" "Desired state"
```

Small item: add `--small`. It starts at `stage:scope` instead of `stage:requirements`.

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

## 4. Reply

One line, then the link. Nothing else — no recap of what you just wrote, they can open it.

> Bakery docs → `bakery-site`. #12

If you guessed the repo, sized it small, or left a gap in the goal, that goes in the same
line:

> Guessing `bakery-site` over `hq` — bakery content, not the system. #12

> Small fix — one file, wording only. #13

## If they ask for several things

One Work Item each, unless they're genuinely one change. Create them all, then one line
listing the links. Work spanning two repos is two Work Items — say which depends on which.
