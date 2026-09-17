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

## Waiting

A Work Item can be paused at any stage. It keeps its stage and resumes from there.

- **Waiting on the user**: a question or decision is needed.
- **Waiting on other work**: another Work Item must finish first.

## Rules

- Every stage change is written as a comment on the Issue: what changed, and why.
- The builder never marks its own work as passed.
- QA never changes the work to make a check pass.
- If the builder finds a requirement is wrong, it stops and records it. It does not quietly change the requirement.
- A Work Item can be **cancelled** at any time by the user.
