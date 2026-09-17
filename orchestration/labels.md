# Labels

Labels hold the state of a Work Item. They can be read at a glance, filtered on a phone, and used later to trigger automation.

**A Work Item always has exactly one `stage:` label.**

## Stage (where the work is)

| Label | Meaning |
|---|---|
| `stage:requirements` | Deciding what must be true when it's done |
| `stage:verification` | Writing the checks that prove it |
| `stage:plan` | Deciding how to do it |
| `stage:build` | Doing the work |
| `stage:qa` | Running the checks |
| `stage:review` | Waiting for the user to look at it |
| `stage:done` | Finished |

## Waiting (why nothing is moving)

| Label | Meaning |
|---|---|
| `waiting:user` | A question or decision is needed |
| `waiting:work` | Another Work Item must finish first |

## Trouble

| Label | Meaning |
|---|---|
| `qa:failed` | The checks failed. Back to build. |
| `qa:stuck` | Failed 3 times. The user needs to step in. |

## Routing

| Label | Meaning |
|---|---|
| `domain:<name>` | Which domain the work belongs to, e.g. `domain:hq-test-sandbox` |
| `workflow:<name>` | Which process to follow, e.g. `workflow:document-update` |

## Creating these labels in a repo

```bash
bash scripts/create-labels.sh <owner>/<repo>
```
