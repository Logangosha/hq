# work-item-lifecycle

**Example only — not run.** The Work Item lifecycle (`orchestration/lifecycle.md`) stays
hard-coded. This shows it on paper in the format. Left out: the `size:small` path,
three strikes, `waiting:work`.

## Trigger

| Kind | Value |
|---|---|
| run | `/new-work-item` (a request in chat) |

## Inputs

| Input | Required | Default | Meaning |
|---|---|---|---|
| request | yes | — | What the user wants done |
| repo | no | chosen from `registry/routing.md` | Where the work goes |

## Stages

| Stage | Kind | Agent | Ask |
|---|---|---|---|
| requirements | agent | requirements | — |
| verification | agent | verification | — |
| plan | agent | planner | — |
| build | agent | builder | — |
| qa | agent | qa | — |
| review | gate | — | Merge the PR, or say what's wrong |

## Arrows

| From | Outcome | To |
|---|---|---|
| requirements | done | verification |
| verification | done | plan |
| verification | bad-requirement | requirements |
| plan | done | build |
| plan | bad-requirement | requirements |
| plan | bad-check | verification |
| build | done | qa |
| build | bad-plan | plan |
| build | bad-requirement | requirements |
| qa | done | review |
| qa | failed | build |
| qa | bad-check | verification |
| qa | goal-missed | requirements |
| review | approved | end |
| review | rejected | requirements |

## Items

| Made by | Starts at |
|---|---|
| trigger | requirements |

## Results

| Where | What |
|---|---|
| the item's Issue | One comment per stage; the merged PR closes it |
