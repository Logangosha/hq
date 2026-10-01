# Contract — parts and their cards

The one place that defines what a part is, what its card says, and what it may call.

## Parts

| Part | What it is | Lives in |
|---|---|---|
| skill | A task the user or an agent asks for, done in a chat | `.claude/skills/<name>/SKILL.md` |
| agent | A worker that does one job | `.claude/agents/<name>.md` |
| workflow | A flowchart of agents and gates | `workflows/<name>.md` ([format](workflows.md)) |
| trigger | What starts a part | `triggers/<name>.md` |

## Triggers

A trigger is its own file, `triggers/<name>.md` in the repo it belongs to; the file name is
its name (`[a-z0-9-]`). `# <name>`, an optional purpose line, then one `| Field | Value |` table:

| Field | Meaning | Required |
|---|---|---|
| Kind | `manual`, `schedule` or `event` | Yes |
| Target | exactly one of `skill:<name>`, `agent:<name>`, `workflow:<name>` | Yes |
| When | `schedule`: a 5-field cron, UTC, numbers only (`*`, `a`, `a-b`, `*/s`, `a-b/s`, lists; day of week 0–7). `event`: the event name. `manual`: leave out | By kind |
| Ask | One line passed to the target; without it the target runs with no ask | No |

- **manual** — ▶ Start and `/run` of a workflow are allowed exactly when a valid manual
  trigger in the repo targets it and the workflow is not view only. A schedule is a kind of
  trigger, not a part of its own.
- **schedule** — starts its target on GitHub, once per cron time, with no dashboard open.
  It runs only if the target exists and its `Started by` includes `schedule`. An agent is
  dispatched like `/run`; a workflow is started like `/run`; a skill runs through the generic
  `skill-runner` agent. The run's Issue names the trigger.
- **event** — reserved. Listed, never run.
- **Per repo.** A repo's triggers apply only to that repo: HQ's are not run or listed for
  domains. A trigger's target may be HQ's own skill, agent or workflow.
- **Broken triggers** (bad kind, target missing or not exactly one, bad cron, a schedule
  whose target isn't started by `schedule`) still show in the dashboard's Triggers list, with
  the reason, and never run.
- **Timing.** The scheduler ticks hourly at :17 UTC (`scripts/runner/schedule.sh`, via the
  stub's `schedule` job). The finest schedule honoured is hourly — a finer cron fires at most
  once per tick. A run may start up to 2 h after its cron time; later is skipped.
  GitHub pauses schedules in a repo idle for 60 days. A domain gets the schedule job by
  re-running `scripts/enable-agents.sh`.
- Examples: `orchestration/trigger-examples/` (read by nothing).

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
default**. Agents are enforced by their frontmatter lists. Skills and workflows are enforced on
runner runs, by `scripts/runner/uses-hook.sh` and `uses-lib.sh`: a Skill call
(`PreToolUse` hook), `scripts/flow-start.sh` / `work-item-start.sh` and `scripts/run-start.sh`
are refused (exit 9) unless the caller's `Uses` names it. A workflow's `Stages` agents
count as its Uses.

- The caller is the skill most recently started in the run (there is no "skill finished" signal). No card, no `Uses` row or a malformed one = calls nothing.
- On a workflow stage run, the workflow's Uses bounds the stage agent's calls too.
- Limits stack: the agent's own `skills:` / `workflows:` still apply; a Uses never widens them.
- Local sessions, and a Work Item stage run's own `work-item` workflow, aren't limited.

## View only

A part whose Started by does not include `user` is **view only**: the dashboard shows a
"View only" tag, with no run or ▶ Start button, and the server refuses to start it.
`work-item` and `small-work-item` are always view only.
