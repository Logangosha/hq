# Capabilities (agents and skills)

These are the reusable agent roles for the Work Item lifecycle. One file per stage.

| Stage | Agent |
|---|---|
| 1. Requirements | `requirements.md` |
| 2. Verification | `verification.md` |
| 3. Plan | `planner.md` |
| 4. Build | `builder.md` |
| 5. QA | `qa.md` |

## What belongs here, and what doesn't

**HQ holds generic capabilities only** — things that work across many repos, domains and
kinds of work. The five above are generic: they know the lifecycle, not the subject.

**Anything specific to one project lives in that project's repo**, in its own
`.claude/agents/` or `.claude/skills/`. A deploy agent that knows one app's infrastructure,
a skill that knows one site's house style — those stay where they apply.

Rule of thumb: if it names a particular app, repo, service or dataset, it doesn't go in HQ.

Planned (F7.5): a project agent will override the HQ one of the same name in that repo.
