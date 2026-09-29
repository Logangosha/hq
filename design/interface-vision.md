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
- Sketches: HQ page, a domain page, a detail page.

Rich results decided: types are text, stat, table, list, chart, file, change; the
dashboard renders a fixed set (custom view later). Pinned results: later.
