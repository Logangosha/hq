# Contract — parts and their cards

The one place that defines what a part is, what its card says, and what it may call.

## Parts

| Part | What it is | Lives in |
|---|---|---|
| skill | A task the user or an agent asks for, done in a chat | `.claude/skills/<name>/SKILL.md` |
| agent | A worker that does one job | `.claude/agents/<name>.md` |
| workflow | A flowchart of agents and gates | `workflows/<name>.md` ([format](workflows.md)) |
| trigger | What starts a part | a `Trigger` row or a `Started by` value |

### Trigger

A **schedule is a kind of trigger**, not a part of its own. The trigger kinds (`run`,
`schedule`, `event`, `work-item`) are listed once, in [workflows.md](workflows.md) "Trigger".

## Card fields

Every part's `## Card` (a workflow's `## Card` is optional) can carry these three fields,
as `| Field | Value |` rows. Other docs link here instead of repeating them.

| Field | Meaning | Allowed values | Required |
|---|---|---|---|
| Product | What the part leaves behind, in one line (an agent card's old `Output` is read as Product) | free text | Yes, on every agent and skill card |
| Uses | What the part may call | `none`, or a comma-separated list of `skill:<name>`, `agent:<name>`, `workflow:<name>`. An agent's Uses is its `skills:` / `workflows:` frontmatter, so its card has no `Uses` row | No; missing = `none` |
| Started by | Who or what may start the part | comma-separated, from `user`, `agent`, `skill`, `workflow`, `label` (a `stage:` label), `schedule` | No; missing = `user`. HQ's own cards always state it |

## Permission = Uses

A part's permission is its Uses list: it may call only what Uses names, and **nothing by
default**. Enforced today for agents (their frontmatter lists); for skills and workflows
it is still to come (#273). A workflow's `Stages` agents count as its Uses.

## View only

A part whose Started by does not include `user` is **view only**: the dashboard shows a
"View only" tag, with no run or ▶ Start button, and the server refuses to start it.
A workflow with a `work-item` Trigger row is view only too.
