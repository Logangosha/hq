# job-hunt

Find new jobs each morning, tailor a résumé for each, apply once the user approves.

## Card

| Field | Value |
|---|---|
| Product | Applications sent once the user approves |
| Uses | none |
| Started by | user, schedule |

## Trigger

| Kind | Value |
|---|---|
| schedule | `0 7 * * *` |
| run | `/run job-hunt in <repo>` |

## Inputs

| Input | Required | Default | Meaning |
|---|---|---|---|
| search | yes | — | Job title or keywords to look for |
| sources | no | LinkedIn | Where to look |

## Stages

| Stage | Kind | Agent | Ask |
|---|---|---|---|
| listing | agent | listing | — |
| resume | agent | resume | — |
| approve | gate | — | Apply to this job with this résumé? |
| apply | agent | apply | — |

## Arrows

| From | Outcome | To |
|---|---|---|
| listing | done | end |
| resume | done | approve |
| approve | approved | apply |
| approve | rejected | resume |
| apply | done | end |

## Items

| Made by | Starts at |
|---|---|
| trigger | listing |
| listing | resume |

## Results

| Where | What |
|---|---|
| each item's Issue | Each stage's comment; `apply` records the application, then the Issue closes |
| the run's Issue | Summary: how many new jobs the listing agent opened |
