# Capabilities (agents and skills)

These are the reusable agent roles for the Work Item lifecycle. One file per stage.

| Stage | Agent |
|---|---|
| 1. Requirements | `requirements.md` |
| 2. Verification | `verification.md` |
| 3. Plan | `planner.md` |
| 4. Build | `builder.md` |
| 5. QA | `qa.md` |
| Scope (small items) | `scope.md` |

## What belongs here, and what doesn't

**HQ holds generic capabilities only** — things that work across many repos, domains and
kinds of work. The agents above are generic: they know the lifecycle, not the subject.

**Anything specific to one project lives in that project's repo**, in its own
`.claude/agents/` or `.claude/skills/`. A deploy agent that knows one app's infrastructure,
a skill that knows one site's house style — those stay where they apply.

Rule of thumb: if it names a particular app, repo, service or dataset, it doesn't go in HQ.

Planned (F7.5): a project agent will override the HQ one of the same name in that repo.

## The agent-file standard

Every agent file follows this — HQ's own `.claude/agents/` and a repo's own. Detail scales
with the agent: there's no fixed number of parts or length, just cover what the job needs.

### Frontmatter

| Field | What it's for |
|---|---|
| `name` | The agent's id. |
| `description` | What it does and when to use it — Claude picks an agent by this. |
| `tools` | The fewest tools the job needs. Every extra tool is something the agent can misuse. |
| `model` | Which model runs it. |
| `effort` | How much reasoning effort it gets. |

### Body

- **Purpose** — what the agent is for, and when to use it.
- **Inputs** — what it needs from the ask, each detail marked required or given a default.
- **Output** — what it hands back, a report or changed files, and where that lands.
- **Boundaries** — what it must never do.
- **Done check** — how it knows its work is finished *and* correct, not just finished.
- **Evals** — 2–3 test asks, each paired with what a good result looks like.

## Writing an agent file

- **Point to where information lives, don't paste it.** A pasted copy goes stale; a path
  stays true.
- **Explain the why behind each rule.** The agent can then handle a case the rule didn't
  foresee.
- **Include an example of good output.** An example is clearer than a description.
