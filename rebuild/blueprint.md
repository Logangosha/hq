# HQ Rebuild — Blueprint v0

Output of a design conversation (Oct 2026). Nothing is built yet. **Decided** = the owner confirmed it; **Leaning** = recommended, not yet confirmed.

## Why rebuild
- The old HQ grew faster than it was understood. The goal this time: understand every part.
- It was welded to GitHub (domain = repo, Work Item = Issue, done = merged PR, agents in Actions). That made it slow (demos), permission-heavy, and code-only.
- Non-coders should be able to use it. Code is one kind of work, not the only one.

## Scope
**HQ is a private control center, run on a computer you own, where a household or small group builds, runs and trusts its own agents. Each domain gets custom skills, agents, workflows and connectors; HQ runs them, gates them and records them.**

- **In:** domains · custom building blocks · triggers · the record · approvals · resource permissions · artifact catalog · one UI for laptop and phone
- **Out:** multi-tenant SaaS · roles beyond "member" · storing the user's data · its own agent engine · a visual agent builder · person-to-person chat · a coding IDE

**Success:**
- Logging an expense from a phone takes under 10 s.
- The dashboard opens in under 1 s.
- The owner can explain every file.
- A new domain is running in minutes.
- Nothing irreversible happens without someone's OK.

## Model
| Object | What it is |
|---|---|
| Domain | an area of life or work: its facts, resources and building blocks |
| Connector | access to an outside system (an MCP server) |
| Skill | one job with inputs and an output; **code** (no AI) or **instructions** |
| Agent | judgment plus a set of skills, a personality and `can-touch` resources |
| Workflow | a fixed sequence: run skill → ask agent → wait for a person |
| Trigger | what starts something: manual, schedule, event, phone |
| Gate | a step that waits for human approval |
| Record | every run: who, inputs, outputs, evidence |
| Artifact | a file or output HQ knows the location of |

Two kinds of work: **quick actions** (seconds, e.g. log an expense) and **projects** (the old Work Item lifecycle becomes one workflow).

## Components
1. **Runner:** a local service that runs skills, agents and workflows via the Claude Agent SDK
2. **Definitions library:** plain files, `shared/` plus `domains/<name>/{domain.md, skills/, agents/, workflows/}`
3. **Record store:** local SQLite
4. **Permission hook:** a PreToolUse hook enforcing each agent's `can-touch` (allowed / ask / never)
5. **Triggers:** manual, schedule, event, phone
6. **Gates and notifications:** approvals reach a phone
7. **Artifact catalog**
8. **UI:** a web page; works on a laptop and from a phone home screen
9. **Builder skills:** new skill/agent/workflow/connector, written to a contract and **test-run as proof**
10. **Remote access:** Tailscale
11. **Backup:** git push of definitions plus a nightly DB backup
12. **Secrets:** kept outside git

## Decisions
| # | Decision | Status |
|---|---|---|
| D1 | Restart from scratch; the old repo stays as reference | Decided |
| D2 | Model: connectors, skills, agents, workflows, triggers | Decided |
| D3 | No permissions on individual actions | Decided |
| D4 | Everyone has the same role | Decided |
| D5 | Local-first orchestration, not cloud | Decided |
| D6 | Permissions on **resources**, enforced by connector, tool list and hook | Leaning |
| D7 | Build on Claude Code / Agent SDK; HQ is the layer on top | Leaning |
| D8 | Definitions are plain files written by Claude; no custom editor | Leaning |
| D9 | All definitions in HQ, grouped by domain; one level of sharing | Leaning |
| D10 | Workflows are readable step lists, not code | Leaning |
| D11 | Definitions in git, the record in SQLite, data stays where it lives | Leaning |
| D12 | GitHub is a backup and a connector, never in the loop | Leaning |
| D13 | Phone access via Tailscale and a home-screen web app; Cloudflare Tunnel later if needed | Leaning |
| D14 | Cheapest thing that works: code skill, then agent, then workflow | Leaning |
| D15 | Agents talk only through a recorded "ask agent" step | Leaning |
| D16 | First version: finance domain end to end (add-transaction skill, transaction-manager agent, monthly-report workflow, phone page, record) | Leaning |

## Changes from the old HQ
| Old | New |
|---|---|
| Domain = a GitHub repo | Domain = an area of life; repos are one resource type |
| Everything is a Work Item (Issue) | Quick actions and projects; the Work Item is one workflow |
| Lifecycle assumed code (PR, merge) | Workflows fit any output: row, PDF, email, code |
| GitHub was the live store and trigger | Local store; GitHub as backup and connector |
| Agents ran in GitHub Actions | Agents run on the owner's computer |
| Permissions = GitHub tokens, apps, scopes | Resource rules the owner defines |
| Built for a coder | Usable from a phone by anyone |
| Grew faster than it was understood | Every feature maps to the model and a use case |

**Kept:** done means proven · the builder doesn't grade its own work · checks name what would fail · the record is the memory · judgment calls get written down · the dashboard's look.

## Open questions
1. Is the HQ computer always on, or do we need an always-on box?
2. Confirm D9: definitions in HQ rather than in each domain's repo?
3. Write the **10 use cases** (vary: codes or not, solo or group, kind of output) and test the model against them.
4. Cost cap per run and per month?
5. Notifications: web push, or ntfy?
6. Domain facts ("our budget categories"): what format?

## Next step
Write the 10 use cases, then the one-page contract for each object.
