# recipe-ideas

The F14.3 test, for `hq-test-recipes`: research recipe ideas, one Issue each, then a
shopping list the user approves.

## Trigger

| Kind | Value |
|---|---|
| run | `/run recipe-ideas in Logangosha/hq-test-recipes` |

## Inputs

| Input | Required | Default | Meaning |
|---|---|---|---|
| theme | no | weeknight dinners | What kind of recipes to look for |

## Stages

| Stage | Kind | Agent | Ask |
|---|---|---|---|
| research | agent | research | — |
| shopping-list | agent | shopping-list | — |
| approve | gate | — | Is this shopping list right? |

## Arrows

| From | Outcome | To |
|---|---|---|
| research | done | end |
| shopping-list | done | approve |
| approve | approved | end |
| approve | rejected | shopping-list |

## Items

| Made by | Starts at |
|---|---|
| trigger | research |
| research | shopping-list |

## Results

| Where | What |
|---|---|
| each item's Issue | The shopping list, then the user's decision |
| the run's Issue | Summary: how many recipe ideas `research` opened |
