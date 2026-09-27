# Features Roadmap — v3

We build one small step at a time. Each feature ends with a **user check** before moving on.
Order rule: get something into the user's hands to try as early as possible.

Older roadmaps: `archive/features-v1.md` (HQ, Work Items, runner, dashboard) and
`archive/features-v2.md` (big requests, agent plans). Their open items stay open there.

## The model

| Noun | What it is |
|---|---|
| **Domain** | A project = one repo. Holds its files, Issues and capabilities |
| **Skill** | Something you type; runs now, in a session |
| **Agent** | One role: job, tools, what it may never do alone, where it reports |
| **Workflow** | Agents in order, started by a trigger |
| **Connection** | An account a domain can reach; secret in GitHub, never in git |

- **Scope:** *generic* capabilities live in HQ and work in every domain; *domain* ones live
  in that repo and win over a generic one of the same name.
- **Triggers:** request · label · schedule · event.
- **Making** a capability is a Work Item. **Running** one is a *run*: it leaves a report,
  or a draft that waits for you.
- Runs happen on GitHub Actions — no computer of yours needs to be on.

---

## F11: A test domain to try everything in
*Goal: one small repo, set up the way every new domain will be.*

Test domain: `hq-test-recipes` — a few recipe files, so agent output is easy to judge.

- [ ] F11.1 Starter files, added by `add-domain` to every new repo: `README.md` (what this
      domain is), `CLAUDE.md` (rules for agents here), empty `.claude/agents/`,
      `.claude/skills/` and `workflows/`
- [ ] F11.2 Create `hq-test-recipes` (asking first) with 3–4 recipe files
- [ ] ✅ User check: open the repo. Is it clear what it is and where things go?

## F12: Run an agent on request
*Goal: `/run <agent> in <repo>` starts that agent on GitHub; the result lands where you
can see it.*

- [ ] F12.1 Domain stub gains a request trigger (`workflow_dispatch`: agent + ask); logic
      in `scripts/runner/`
- [ ] F12.2 A run's result is an Issue labelled `run` in that domain; file changes come as
      a PR on it
- [ ] F12.3 `/run` skill in HQ
- [ ] F12.4 Domain agent `shopping-list` in the test repo: builds a shopping list from
      chosen recipes, as a PR
- [ ] ✅ User check: run it from HQ (and from your phone). Is the result right and easy to find?

## F13: A generic agent that works in any domain
*Goal: one agent in HQ, run in any repo, that learns the repo before it answers.*

- [ ] F13.1 Generic `research` agent in HQ: reads the domain, searches the web, posts a
      report with sources. Read-only
- [ ] F13.2 Run it in the test repo and in `hq` with the same `/run`
- [ ] ✅ User check: are both reports useful and grounded in the right repo?

## F14: Workflows — agents in a chain
*Goal: a file in `workflows/` names its trigger and its agents in order; `/run` starts it.*

- [ ] F14.1 Workflow format: trigger, agents in order, connections, where it reports
- [ ] F14.2 Test workflow in the test repo: `research` → `shopping-list`
- [ ] ✅ User check: run it. Did each agent hand off correctly?

## F15: Scheduled runs
*Goal: a workflow runs by itself on a schedule.*

- [ ] F15.1 Schedule trigger from the workflow file (GitHub cron)
- [ ] F15.2 Test: the F14 workflow weekly; its runs show on the dashboard
- [ ] ✅ User check: did it run with your computer off?

## F16: What can X do?
- [ ] F16.1 `/capabilities <repo>`: its agents, skills and workflows, generic ones included
- [ ] F16.2 The same on the dashboard, per domain
- [ ] ✅ User check: can you tell at a glance what each domain can do?

## F17: Cross-domain agents
- [ ] F17.1 A generic workflow in HQ that runs over every domain
- [ ] F17.2 First one: `librarian` — keeps an index of what's in each domain, read-only
- [ ] ✅ User check: ask the librarian where something is. Does it know?

## Later
- Connections (email, accounts) — carried from F10.6–F10.8 in `archive/features-v2.md`
- Event triggers (email arrives, PR merges)
