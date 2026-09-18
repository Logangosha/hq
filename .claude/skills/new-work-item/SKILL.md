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

## 3. Create it

```bash
bash scripts/create-work-item.sh <owner>/<repo> "Title" "Current state" "Desired state"
```

Long or formatted goals: pass `-` as the third argument and pipe the body in.

The script handles the `Work Item:` prefix, the labels and `stage:requirements`. Don't
add labels by hand.

## 4. Reply

One line, then the link. Nothing else — no recap of what you just wrote, they can open it.

> Bakery docs → `hq-test-sandbox`. #12

If you guessed the repo, or left a gap in the goal, that goes in the same line:

> Guessing `hq-test-sandbox` over `hq` — bakery content, not the system. #12

## If they ask for several things

One Work Item each, unless they're genuinely one change. Create them all, then one line
listing the links. Work spanning two repos is two Work Items — say which depends on which.
