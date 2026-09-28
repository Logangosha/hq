# Workflows — the model

A **workflow** is a flowchart that HQ runs. The Work Item lifecycle (`lifecycle.md`) is
one flowchart, hard-coded today. Workflows let any domain describe its own and have the
same engine run it. Roadmap: F14 in `features.md`. The file format is below.

## Parts

| Part | What it is | Job-hunt example |
|---|---|---|
| **Workflow** | A flowchart, in a file in the domain's `workflows/` | `workflows/job-hunt.md` |
| **Stage** | One box in the flowchart | "tailor résumé" |
| **Agent** | Does the work at a stage | the résumé agent |
| **Gate** | A stage where the user decides, not an agent | "approve this application?" |
| **Arrow** | Where an item goes next, by how the stage went | approved → apply; rejected → résumé |
| **Item** | One thing moving through the flowchart. A GitHub Issue — its memory | one job listing |
| **Trigger** | What starts the workflow | `/run`, a schedule, an event |
| **Runner** | HQ's engine on GitHub: moves items along arrows, starts the next agent | the Work Item runner, generalised |

## How it runs (job hunt)

1. Trigger: each morning the listing agent opens one Issue per new job.
2. Each Issue moves to "tailor résumé"; the résumé agent posts a tailored résumé on it.
3. Gate: the Issue waits for the user.
4. Approve → "apply". Reject with a comment → back to the résumé agent, comment included.
5. The apply agent applies and records it on the Issue, which closes — the same job is
   never applied to twice.

## What the user does

| To | Do |
|---|---|
| Create a workflow | Describe it in chat → a Work Item; an agent writes the file |
| Start it | `/run <workflow> in <repo>`, or its schedule |
| See what's happening | Dashboard: each workflow as a board, items in their stages (F15) |
| Decide | Items at a gate show as "needs you"; approve or reject there or with `/review` |
| Change it | Say what to change → a Work Item |

## Rules

- **Where it lives:** generic workflows in HQ's `workflows/`, domain ones in the domain's.
  A domain's workflow wins over HQ's of the same name — the same rule as agents.
- **The Issue is the memory**, as for Work Items: every result and decision goes on it.
- **Anything outward-facing waits at a gate** — sending, applying, posting, paying.
- **The Work Item lifecycle stays hard-coded.** `workflow-examples/work-item-lifecycle.md`
  shows it written in the format — on paper only, not run (the small path, three strikes
  and blockers aren't covered). Later it may become HQ's own workflow file.
- **HQ's `workflows/`:** none yet. Examples of the format are in `workflow-examples/`.

## Format

A workflow is one plain-Markdown file, `workflows/<name>.md`. **The file name is the
workflow's name.** No frontmatter. It starts with `# <name>` and one line of purpose, then
these `## ` sections, each holding one table. Examples: `orchestration/workflow-examples/`
(`job-hunt.md`, `recipe-ideas.md`, and `work-item-lifecycle.md` — the lifecycle on paper).

| Section | Meaning | Required / default |
|---|---|---|
| Trigger | What starts a run | Required, at least one row |
| Inputs | What a run needs to know | Optional; default none |
| Stages | The boxes: agents and gates | Required, at least one row |
| Arrows | Where an item goes next, by outcome | Required |
| Items | How items are created and where they start | Required |
| Results | Where results are reported | Optional; default: each stage comments on its own item's Issue |

### Trigger — `| Kind | Value |`

- `run` — `/run <name> in <repo>`.
- `schedule` — a cron string in backticks, UTC, e.g. `` `0 7 * * *` ``.
- `event` — reserved for later; runners ignore it.

### Inputs — `| Input | Required | Default | Meaning |`

Same standard as `.claude/agents/README.md`: each input is `yes` with Default `—`, or `no`
with a default. `/run` asks for any missing required input.

### Stages — `| Stage | Kind | Agent | Ask |`

- **Stage** — an id, `[a-z0-9-]+`, ASCII so it is safe in a label.
- **Kind** — `agent` or `gate`.
- **Agent** — for `agent`, the file name in `.claude/agents/` (the domain's first, then
  HQ's). For `gate`, `—`.
- **Ask** — for `gate`, the question put to the user. For `agent`, `—`.

The first row is not special; the Items table says where items start.

### Arrows — `| From | Outcome | To |`

One row per arrow, so a stage can have many, to different stages.

- **Outcome** — `done` or `failed` at an agent stage; `approved` or `rejected` at a gate.
  An agent stage may also use any other lowercase outcome (e.g. `bad-check`), to tell
  several bounces apart.
- **To** — a stage (an earlier one makes a loop) or `end`, where the item's Issue closes.
- An outcome with no arrow puts the item on `waiting:user`.

### How an outcome is signalled

| Stage | Signal |
|---|---|
| Agent | Its stage comment ends with a line `Outcome: <outcome>`. A crash, or no such line, is `failed`. |
| Gate | A user comment starting `/approve`, or merging a PR that says `Closes #<n>`, is `approved`. Any other user comment is `rejected`. |

**A rejection's comment** reaches the next agent through the Issue digest
(`scripts/runner/issue-digest.sh`), which always includes every human comment; the
rejecting one is the latest.

### Items — `| Made by | Starts at |`

- `trigger` — each run makes one Issue (the run's), starting at the named stage.
- `<stage>` — that stage opens one Issue per thing it finds (a job, a recipe idea), each
  starting at the named stage.

### Stage on the Issue

Two labels: `flow:<workflow>` (fixed) and `step:<stage>` (swapped as the item moves).
Never `stage:` (the runner starts an agent on it), and not `waiting:*` or `workflow:<name>`
(meanings already in `labels.md`). Listed in `labels.md`.

### Results — `| Where | What |`

Where a run's output is reported. Default: every stage comments on its own item's Issue,
and a `trigger` item's Issue also gets the run summary.

### Reading it with a script

Bash, grep, sed and awk only — no jq, yq, Python or Node. A section is the lines between
`## <Field>` and the next `## `. Its rows are the lines starting `|`, minus the header row
and the `|---` line. Split cells on `|`, trim spaces, strip backticks.

```bash
# usage: rows.sh <file> <Section>   — prints one row per line, cells tab-separated
awk -v sec="$2" '
  /^## / { on = ($0 == "## " sec); n = 0; next }
  on && /^\|/ { n++; if (n > 2) {
    gsub(/`/, ""); split($0, c, "|"); out = ""
    for (i = 2; i < length(c); i++) { gsub(/^ +| +$/, "", c[i]); out = out (i > 2 ? "\t" : "") c[i] }
    print out } }' "$1"
```

Run it once per section: `rows.sh workflows/job-hunt.md Arrows`. The `n > 2` skips the
header and `|---` lines.
