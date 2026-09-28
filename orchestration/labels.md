# Labels

Labels hold the state of a Work Item. They can be read at a glance, filtered on a phone, and used later to trigger automation.

**An open Work Item always has exactly one `stage:` label** — except while blocked
(`waiting:work`), when it has none: it runs no stage until its blockers — any number, in
any domain — have all merged. Merging the PR closes the Issue — closed means done, so
there is no done label.

## Stage (where the work is)

| Label | Meaning |
|---|---|
| `stage:requirements` | Deciding what must be true when it's done |
| `stage:verification` | Writing the checks that prove it |
| `stage:plan` | Deciding how to do it |
| `stage:build` | Doing the work |
| `stage:qa` | Running the checks |
| `stage:review` | Waiting for the user to look at it |

A failed QA or a bounce moves the `stage:` label back. See `lifecycle.md`.

## Waiting (why nothing is moving)

| Label | Meaning |
|---|---|
| `waiting:user` | A question or decision is needed, or a stage was reached 3 times |
| `waiting:work` | One or more other Work Items must all finish first |

## Workflow

| Label | Meaning |
|---|---|
| `workflow:<name>` | An approved overlay applies, e.g. `workflow:document-update`. Added only once one exists. |

The repo already says which domain a Work Item belongs to, so there is no domain label.

## Workflow items

Items of a workflow file (`orchestration/workflows.md`). Created by the runner (F14.2), not by `create-labels.sh`. Never `stage:` — that starts a Work Item agent.

| Label | Meaning |
|---|---|
| `flow:<workflow>` | The item belongs to this workflow, e.g. `flow:job-hunt` |
| `step:<stage>` | The item is at this stage of its workflow, e.g. `step:resume` |

## Creating these labels in a repo

```bash
bash scripts/create-labels.sh <owner>/<repo>
```
