# Workflows — the model

A **workflow** is a flowchart that HQ runs. The Work Item lifecycle (`lifecycle.md`) is
one flowchart, hard-coded today. Workflows let any domain describe its own and have the
same engine run it. Roadmap: F14 in `features.md`. The file format itself is F14.1; this
page is the model it must fit.

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
- **The Work Item lifecycle stays hard-coded** until the format handles its loops, gates
  and blockers. Then it becomes HQ's own workflow file.
