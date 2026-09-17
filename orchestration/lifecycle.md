# Work Item Lifecycle

Every Work Item moves through these stages, in order.

```
REQUIREMENTS → VERIFICATION → PLAN → BUILD → QA → HUMAN REVIEW → DONE
      ▲                                ▲      │         │
      │                                └ fail ┘         │
      └─────────────── rejected (with comments) ────────┘
```

## Stages

| # | Stage | Who | What happens | Ready to move on when... |
|---|---|---|---|---|
| 1 | **Requirements** | Requirements agent | Write what must be true when the work is done | Each requirement is numbered (R1, R2, ...) and clear |
| 2 | **Verification** | QA agent | Write one or more checks for each requirement | Every requirement has at least one check (V1, V2, ...) |
| 3 | **Plan** | Planner agent | Decide how to do the work | Every requirement is covered by the plan |
| 4 | **Build** | Builder agent | Do the work, using the requirements and plan | Work is finished and linked (PR, commit, or file) |
| 5 | **QA** | QA agent (not the builder) | Run every check and record the result as evidence | Every check has passed |
| 6 | **Human review** | The user | Look at the result | The user approves or rejects |
| 7 | **Done** | — | Work is complete | — |

## Loops

- **QA fails** → back to **Build**, with a note on what failed.
- **QA fails 3 times** → stop and ask the user.
- **The user rejects** → back to **Requirements**, with the user's comments.

## When the user is involved

The user drops in twice, and no more than that:

1. **At the start**, to say what they want.
2. **At stage 6**, to review the finished result.

Everything between those two points is the agents' problem. Do **not** stop to get
requirements or a plan approved.

The only other reason to interrupt them is that the work is genuinely stuck:

- The work would be destructive, or can't be undone.
- Two reasonable readings of the request lead to very different results, and picking
  wrong would waste real effort.
- Something outside the agents' control is blocking it (access, a missing decision only
  the user can make, a bill to pay).
- QA has failed 3 times.

Anything less than that is a decision the agents make themselves. **Choose the option
that is easiest to undo, write the choice and the reason in the Decisions section, and
flag it at stage 6.** The user can reject it then, and rejection is cheap because the
choice was reversible.

## Waiting

A Work Item can be paused at any stage. It keeps its stage and resumes from there.

- **Waiting on the user**: the work is stuck for one of the reasons above.
- **Waiting on other work**: another Work Item must finish first.

## Writing a good check

This is the most important rule in the system. It's what stops an agent from claiming
success without proof.

> **A check must name what to look at, and what would make it fail.**

| Good | Bad |
|---|---|
| Open `docs/menu.md`. It must not contain the word "daily". Fail if it does. | Confirm the menu is accurate. |
| Run `npm test`. All tests must pass. Fail on any error. | Make sure the code works. |
| Each claim in section 2 must have a source link. Fail if any claim has none. | Check that the research is solid. |

The user should be able to read the checklist and answer one question:
*"If all of these pass, am I happy?"*

## Workflows

The stages above are all a Work Item needs. **There is no workflow to choose.**
Claude works out the details from the work itself: checking a document means reading it,
checking code means running it.

A **workflow** is an optional short overlay that gets added later, only after the same
kind of work has come up several times. It holds the lessons learned, never a copy of
the stages. If no workflow exists, follow this file and carry on.

To make that possible, at the end of every Work Item the agent records on the Issue
any judgment call it had to make. Those notes are the raw material for a future workflow,
which the user approves before it becomes a rule.

## Rules

- Every stage change is written as a comment on the Issue: what changed, and why.
- The builder never marks its own work as passed.
- QA never changes the work to make a check pass.
- If the builder finds a requirement is wrong, it stops and records it. It does not quietly change the requirement.
- A Work Item can be **cancelled** at any time by the user.

## How the Issue is written

Body layout (see the Work Item template):

```
**Stage:** <n> <name> · **PR:** <number or —>

## Goal
**Current state:** ...
**Desired state:** ...

## 1..6 <stage> — pending
```

- Only the **Stage** line and **PR** number change as work moves. Everything else is
  appended by the agent that owns that stage.
- A stage heading becomes `## 3. Plan — planner ✅` plus 1–2 lines of what was done.
- Requirements live under stage 1, their proofs under stage 2, their results under stage 5.
- A proof must name a file or command and what makes it fail.
- Detail, evidence, commands and failures go in the **comments**, not the body.
