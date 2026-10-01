# Work Item

The Work Item lifecycle (`orchestration/lifecycle.md`), drawn. View only: the hard-coded runner still does the work.

## Card

| Field | Value |
|---|---|
| Product | The Work Item lifecycle, drawn |
| Uses | none |
| Started by | agent, skill |

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
