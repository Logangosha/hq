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

## When an agent finds a problem with earlier work

No agent checks its own output. Each stage is the first fresh look at the one before it,
so finding a problem upstream is normal work, not an exception.

**The mechanism is always the same: the `stage:` label goes back, and a comment says why.**
The label is the queue. A fresh agent for that stage picks the item up and reads the
comments above it. There is no separate "needs rework" state to keep in sync.

### Three responses, chosen by cost

| Response | When | What happens |
|---|---|---|
| **Fix in place** | The problem is factual and objectively correctable — a miscount, a wrong path, a typo'd filename | The finding agent corrects it in **its own** comment and says it did. No bounce. Never for anything needing judgment. |
| **Bounce** | The problem needs a decision the earlier stage owns — something is wrong, contradicts something else, or is out of scope | The `stage:` label goes back. The comment names what's wrong and what would settle it. |
| **Stop** | The goal itself is wrong or can't be done | Add `waiting:user` and ask. |

Bouncing is expensive — it re-runs a whole stage. Fix in place when you honestly can,
bounce when a judgment call belongs to someone else.

### Rules

- **Scan everything, bounce once.** Keep reading after the first problem and report them
  all in one comment. Don't do your own stage's work first — it's wasted if the earlier
  stage changes.
- **Nothing is ever rewritten.** A correction is a new comment. The wrong version stays
  where it is, with the correction below it. The Issue is the memory, and the memory
  includes the mistake.
- **A re-run is a new comment**, headed `## 1b. Requirements (re-run) — requirements ✅`,
  so the Issue still reads top to bottom.
- **Three strikes at any stage.** If a Work Item lands on the same stage a third time,
  stop and ask the user. Two agents must never ping-pong on a disagreement neither can
  resolve.

## Loops

- **QA fails** → back to **Build**, with a note on what failed.
- **The user rejects** → back to **Requirements**, with the user's comments.
- **Any stage reached 3 times** → stop and ask the user.

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
- A Work Item has landed on the same stage 3 times.

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
- **No agent checks its own output.** Each stage checks the one before it. The builder
  never marks its own work as passed, and an agent that spots its own mistake after
  posting leaves it for the next stage rather than quietly editing it.
- QA never changes the work to make a check pass.
- If the builder finds a requirement is wrong, it stops and records it. It does not quietly change the requirement.
- A Work Item can be **cancelled** at any time by the user.

## How the Issue is written

- **Body: the goal only** — current state and desired state. It is written once and not
  edited again.
- **Each stage is its own comment**, headed `## 3. Plan — planner ✅`, with 1–2 lines of
  what was done plus any evidence. Comments are already in order, so the Issue reads top
  to bottom.
- The `stage:` **label** shows where the work is. The PR is linked by GitHub. Neither is
  repeated in the body.
- Requirements go in the stage 1 comment, their proofs in stage 2, their results in stage 5.
- A proof must name a file or command and what makes it fail.

## How the user approves or rejects

- **Approve = merge the PR.** The PR says `Closes #<n>`, so merging closes the Work Item.
  Nothing else to click. Works from the GitHub phone app.
- **Reject = comment** what's wrong. An agent picks the comment up, moves the Work Item
  back to the stage that needs fixing, and works on it again.
- No labels for this. Merged means approved.
