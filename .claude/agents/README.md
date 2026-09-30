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

HQ also holds generic, non-stage agents — run one-off via `/run <agent> in <repo>: <ask>`,
outside the lifecycle:

| Agent | What it does |
|---|---|
| `research.md` | Answers a question about a repo, read-only. `/run research in <repo>: <question>` |

## What belongs here, and what doesn't

Skill, agent or workflow — which shape a capability takes: `orchestration/workflows.md`.

**HQ holds generic capabilities only** — things that work across many repos, domains and
kinds of work. The agents above are generic: they know the lifecycle, not the subject.

**Anything specific to one project lives in that project's repo**, in its own
`.claude/agents/` or `.claude/skills/`. A deploy agent that knows one app's infrastructure,
a skill that knows one site's house style — those stay where they apply.

Rule of thumb: if it names a particular app, repo, service or dataset, it doesn't go in HQ.

Planned (F7.5): a project agent will override the HQ one of the same name in that repo.

## Skills on a page

A skill is `.claude/skills/<name>/SKILL.md`. The dashboard's Skills list follows the same
inheritance as agents:

- A domain page shows HQ's shared skills plus the domain's own `.claude/skills/`.
- Same name: the domain's skill wins, and its entry says it replaces HQ's.
- `hq-only: true` in a skill's frontmatter keeps it on HQ's page only; domains don't inherit it.
- `dashboard-hidden: true` shows it on no page (HQ's file only; a domain's own skill of that name still shows). Use it for a skill that duplicates something the dashboard already does (e.g. `review`, `run`, `work-items`); any such skill can have it.
- No field = shared.

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
- **Output** — what it hands back, a report or changed files, and where that lands. Write results as blocks where they fit: [blocks.md](../../orchestration/blocks.md).
- **Boundaries** — what it must never do.
- **Done check** — how it knows its work is finished *and* correct, not just finished.
- **Evals** — 2–3 test asks, each paired with what a good result looks like.
- **Card** — how the dashboard draws the agent; see below.

## Self-description (card)

An agent describes itself in a `## Card` section at the **end** of its own `.md` file, as
Markdown tables. It sits in the body, not the frontmatter, so the runner and Claude Code
never see it. `python3 scripts/agent-cards.py <dir or file>...` reads the cards and prints
JSON for the dashboard.

| Field | Required? | Allowed values |
|---|---|---|
| `Name` | required | Display name, one line. |
| `Icon` | required | A [Material Symbols](https://fonts.google.com/icons) icon name (lowercase, digits, `_`), e.g. `route`. |
| `Purpose` | required | One line. |
| `Inputs` | required | `text`, `files`, `text, files` or `none`. `none` = the dashboard shows no input box. |
| `Output` | required | One line: what it produces, e.g. "an answer comment" or "a PR". |

Optional `### Shortcuts` table, `| Label | Kind | Ask | Needs |`:

| Column | Required? | Allowed values |
|---|---|---|
| `Label` | required | Button text. |
| `Kind` | required | `question`, `log` or `job` — nothing else. |
| `Ask` | required | The ask it sends the agent. |
| `Needs` | optional | What the user must fill in. Blank = nothing. |

No `|` inside a cell. No shortcuts section = zero shortcuts; a stage agent (one started by
a `stage:` label, not by the user) may have none.

**Domain agents** (a domain repo's `.claude/agents/`) use the same format; it is optional
for them. A file with no card still shows, using `name` and `description`.

Example:

```markdown
## Card

| Field | Value |
|---|---|
| Name | Finance |
| Icon | account_balance |
| Purpose | Answers questions about the budget and logs spending. |
| Inputs | text, files |
| Output | An answer comment on the run Issue |

### Shortcuts

| Label | Kind | Ask | Needs |
|---|---|---|---|
| Monthly summary | question | Summarise this month's spending by category. | |
| Log a purchase | log | Record this purchase in the ledger. | Amount, date and shop |
```

## Writing an agent file

- **Point to where information lives, don't paste it.** A pasted copy goes stale; a path
  stays true.
- **Explain the why behind each rule.** The agent can then handle a case the rule didn't
  foresee.
- **Include an example of good output.** An example is clearer than a description.
