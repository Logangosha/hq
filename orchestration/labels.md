# Labels

Labels hold the state of a Work Item. They can be read at a glance, filtered on a phone, and used later to trigger automation.

**An open Work Item always has exactly one `stage:` label** — except while blocked
(`waiting:work`), when it has none: it runs no stage until its blocker merges. Merging
the PR closes the Issue — closed means done, so there is no done label.

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
| `waiting:work` | Another Work Item must finish first |

## Workflow

| Label | Meaning |
|---|---|
| `workflow:<name>` | An approved overlay applies, e.g. `workflow:document-update`. Added only once one exists. |

The repo already says which domain a Work Item belongs to, so there is no domain label.

## Creating these labels in a repo

```bash
bash scripts/create-labels.sh <owner>/<repo>
```
