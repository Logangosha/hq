# Small Work Item

The small Work Item path (`orchestration/lifecycle.md`), drawn. View only: the hard-coded runner still does the work.

## Card

| Field | Value |
|---|---|
| Product | The small Work Item path, drawn |
| Uses | none |
| Started by | agent, skill |

## Stages

| Stage | Kind | Agent | Ask |
|---|---|---|---|
| scope | agent | scope | — |
| build | agent | builder | — |
| review | gate | — | Merge the PR, or say what's wrong |

## Arrows

| From | Outcome | To |
|---|---|---|
| scope | done | build |
| build | done | review |
| build | bad-plan | scope |
| review | approved | end |
| review | rejected | scope |

## Items

| Made by | Starts at |
|---|---|
| trigger | scope |
