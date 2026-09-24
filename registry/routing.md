# Routing

How a plain request becomes a Work Item in the right place.

## The only question

**Which repo do the files this work touches belong to?**

The user usually names the repo — use it. Otherwise list the domains with
`bash scripts/list-domains.sh` and match the request against each repo's description.
Route on the work, not on the words — "write up the bakery hours" is a docs change in the
bakery repo, not a writing project.

## Rules

1. **Only domains.** A repo without the Work Item workflow isn't one — nothing would run.
   Offer `/add-domain` instead.
2. **Work on the system itself goes to `hq`** — the lifecycle, the agents, the scripts,
   the roadmap.
3. **Two domains fit** → pick the one that owns the files being changed. If the work
   genuinely spans both, it's two Work Items, one per repo. Say so and link them.
4. **No domain fits** → stop. Don't invent a repo and don't force it into the closest one.
   Tell the user what's missing and propose a domain in one line. Creating a repo needs
   their yes.
5. **Unsure between two** → guess, put the guess in the proposal, and create it only on
   the user's yes. Routing is reversible (`gh issue transfer`), so a wrong guess is cheap.
   Don't make the user choose.

## Workflow

Nothing to route. The lifecycle is the same for every Work Item, and no workflow is
chosen up front — see "Workflows" in `orchestration/lifecycle.md`. A `workflow:` label
appears only after the user has approved an overlay for that kind of work.

The reply format is in the `new-work-item` skill.
