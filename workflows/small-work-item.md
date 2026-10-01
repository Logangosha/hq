# Small Work Item

The small Work Item path (`orchestration/lifecycle.md`), drawn. View only: the hard-coded runner still does the work.

## Trigger

| Kind | Value |
|---|---|
| work-item | `scripts/create-work-item.sh --small` |

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
