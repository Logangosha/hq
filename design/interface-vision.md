# HQ interface — vision

Design exploration, in progress. Decisions so far; open points at the end.

## Who

**The director** — one person. HQ is scaffolding for orchestrating AI agents across
domains (a life, a company, a child's program, a codebase). Agents are the **staff**; the
director directs, gets information, and makes the final calls.

## Surfaces

| Surface | Style | For |
|---|---|---|
| Claude Code on `hq` (laptop, phone) | Conversation | Asking, telling, commanding; real conversations; creating or changing agents, workflows, domains |
| Dashboard (laptop only) | Visual, with buttons | The 20% of actions that do 80% of the work: see what I can do, what's happened, how it's going; act on it |
| GitHub | Hidden backend | Readable like a log; never required, no PR lingo |

## Structure

**Sidebar:** HQ at the top (special icon, the landing page), then every domain. Badges show
what needs you. Scales to 20+ domains.

| Page | Role | Shows |
|---|---|---|
| **Domain page** | Workspace | Agents (shortcuts, input box, latest headline) · workflows · activity · capabilities · its info |
| **HQ** | A domain **and** the control tower | Same layout as every domain (its agents are the generic ones), **plus** a top section *Across all domains*: Needs you · Work Items and workflow runs grouped by domain · domain health · costs |
| **Detail page** | One thing, full screen | Review · Answer · Result · Run. **← Back** to return. No drawers: big changes need the whole page |

- **Noise rule:** HQ's top section shows only what's orchestrated (Work Items, workflow
  runs) and decisions. Quick Questions and Logs stay on their domain's page.
- A domain page shows its own slice (its Work Items, runs, decisions); HQ shows every
  domain's slice. Same data, two heights.
- Commands (new Work Item, run, add/remove domain, setup) stay in Claude Code on `hq`; the
  dashboard shows their effects.
- Later, if HQ's page gets crowded: split the top section into its own control tower.

## Talking to an agent

One input box per agent. The user just types (or drops a file); the agent decides what it
became:

| Outcome | When | Feels like |
|---|---|---|
| **Question** → Answer | Nothing needs changing | A reply |
| **Log** → Logged | It files what the user gave it | A receipt, with Undo |
| **Job** → Run → Result | It must think, make or find something | A card that progresses |

Word for the third: **Job** (leaning) or Task — undecided.

**Shortcuts:** saved Questions, Logs and Jobs an agent offers ("What's my net worth?",
"Log today's workout"). Defined in Claude Code via a Work Item. Shown as buttons on the
agent, most-used ones on home.

## Patterns the dashboard draws the same way for every agent

| Pattern | Shows |
|---|---|
| **Run** | Who's working, which step, how long, last thing done; queued → working → waiting on you → finished / failed (plain-words reason + Retry) |
| **Decision** | What's waiting, why, the evidence; Approve / Send back with comment / open in Claude Code. Covers Work Item review, workflow gates, anything outward-facing |
| **Result** | Headline, then the full answer, report or changes; which agent, when, link to its Run |

Chains: Question → Answer · Log → Logged · Job → Run → (Decision →) Result.

Agents must **describe themselves** (patterns supported, shortcuts, inputs) so the
dashboard can draw them generically — a later addition to `.claude/agents/README.md`.

## Agent card (draft)

```
┌ Finance ─────────────────────────┐
│ [Net worth?] [Add transaction]   │  shortcuts
│ [ Type or drop a file…       ]   │  open input
│ ─ Latest ─────────────────────── │
│ Net worth: $X  ▁▂▃▅▆  (2h ago)   │  results feed
└──────────────────────────────────┘
```

## Decided

- **Files as input — V1.** Dropped files are saved into the domain repo (e.g. `inbox/`);
  the agent reads them there. Git keeps history forever: no ID documents.
- **Rich results** — agents write one shared format (text, tables, chart block, files);
  the result lives on the Issue; the dashboard renders it nicely.
- **Privacy** — domains are private repos (only `hq` is public and holds no personal
  data). Budgets and transactions are fine; ID numbers, account numbers, passwords never.
  Private repos use GitHub's free monthly Actions minutes.
- **Single user.** Messages to others go out through Connections, always past a Decision.
- **Delight** is a principle: small animations and polish throughout.

## Later

Watch and Schedule (part of Run) · Connections (email, bank) · speed of agent runs ·
newcomer onboarding · a blueprint gate after Plan in the Work Item lifecycle.

## Open

- Job vs Task.
- **Look and feel — next step.** Three directions were shown for the HQ page (same
  structure, different feel):
  - **A · Calm** — lots of space, rows with hairlines, almost no color. Quiet notebook.
  - **B · Dense** — counts strip (needs you, running, failed, cost), rows with domain,
    title, stage tag, age. Pro tool, like Linear.
  - **C · Warm** — serif greeting, a color per domain, tinted cards. Personal assistant.
  - Claude's guess: A + B mix (calm by default, stages visible), keep C's domain colors.
    User hasn't picked yet.
  - Round 2, same layout in six visual styles. **User rules out:** a dark sidebar; hierarchy
    by big type alone; a color per domain everywhere (color yes, but sparing); rounded
    everything. Blueprint grid (square corners, visible lines, mono labels) is interesting
    but too harsh.
  - Round 3, between soft cards and grid, one accent color only: 7 softened grid ·
    8 square cards on gray · 9 ledger · 10 quiet frame, one accent. Awaiting reaction.

## Page sections (agreed, naming nearly final)

| Section | On | Scope |
|---|---|---|
| *Waiting section* (name open: Waiting on you, Your turn, Inbox, To do, Up next, Desk) | Every page | Two groups — **to act on** (review, decide, answer) and **to read** (report ready, job finished). Leaves once acted on or opened. On HQ: all domains, tagged by domain |
| Agents | Every page | Shortcuts, input box, latest result. HQ's are the generic ones |
| Running | Every page | Live Jobs and workflow runs. On HQ: all domains |
| Workflows | Every page | Flows you can **Start**, with each one's last run |
| History | Every page | Everything finished: answers, logs, results, failures. Searchable and sortable (newest, oldest, by agent, by kind) |
| About | Every page (button by the name) | Full-page guide: what the domain is, what belongs, its agents, workflows, what you can ask |
| Domains | HQ only | One line each: waiting, running, failed |
| Cost | HQ only | This month per domain — agent spend, Actions minutes, vs last month; click through for detail |

HQ shows no separate waiting/running of its own — its items appear in the all-domain lists.
- Then sketch: HQ page, a domain page, a detail page → Design System artifact → clickable
  prototype (Design artifact) → build Work Item for `dashboard/`.

## Working method

Exploration happens in chat with Claude, one step at a time: Claude proposes with a
recommendation, the user reacts. Visual options are drawn inline in chat. Decisions get
written here and committed as they're made.

Rich results decided: types are text, stat, table, list, chart, file, change; the
dashboard renders a fixed set (custom view later). Pinned results: later.
