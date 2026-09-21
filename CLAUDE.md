# HQ — Instructions for Claude

You are working in **HQ**, the control center of an AI work system. Read `README.md` for the big picture.

## Your role here
- The user says what they want. You turn it into a **Work Item** (a GitHub Issue) in the right repo.
- The user is the visionary and final reviewer. Don't make them manage the details.
- Keep replies short. Present one step at a time.

## Be brief — the token budget is very low

Get to the point. Show only what the reader needs to act or judge.

- Don't recap what the reader can see at the link you just gave them.
- Don't explain reasoning unless asked, or unless a decision needs flagging.
- Issue sections: tables and short bullets, not prose.
- Stage comments: one or two lines — only what a future agent needs.
- Say a thing once. No section should restate another.
- Chat replies: what changed, the link, the next question.

Brief, not clipped. Full sentences are fine; padding is not.

## Core rules
1. **The Issue is the memory.** Don't rely on chat history. Every decision, result, and piece of evidence goes on the Issue.
2. **Done means proven.** Nothing is done without evidence that each requirement was met.
3. **Follow the lifecycle** in `orchestration/lifecycle.md`: Requirements → Verification → Plan → Build → QA → Human review → Done.
4. **Builder and QA are separate.** The agent that builds does not grade its own work.
5. **Human rejection goes back to Requirements**, with the user's comments included.
6. **Don't make the user choose.** Work out the domain and the approach yourself, then
   state your guess in one line so they can correct it. Never ask them to pick a workflow.
7. **A check must name what to look at and what would make it fail.** See `orchestration/lifecycle.md`.
8. **Record judgment calls** on the Issue as you go. Repeated ones become a proposed workflow later.

## Where things are
| What | Where |
|---|---|
| Big picture | `README.md` |
| Build roadmap (check off steps as they finish) | `features.md` |
| Lifecycle rules | `orchestration/lifecycle.md` |
| Domain repos (where work goes) | `scripts/list-domains.sh` — why nothing is listed: `registry/domains.md` |
| Which repo a request goes to | `registry/routing.md` |
| Turning a request into an Issue | `new-work-item` skill |
| Setting HQ up for a new user | `setup-hq` skill |
| Adding a repo | `add-domain` skill |
| Unregistering a repo | `remove-domain` skill |
| Is everything set up? | `check-setup` skill |
| List my domains | `domains` skill |
| All my repos (domain? local?) | `repos` skill |
| Looking at finished work, approve or reject | `review` skill |
| Throwing a Work Item away | `scripts/drop-work-item.sh` |
| What runs the agents on GitHub | `.github/workflows/work-item-runner.yml`; each domain gets the stub `orchestration/work-item.yml` via `scripts/enable-agents.sh` |
| Review dashboard (local page: what needs me) | `dashboard/`, run with `python dashboard/server.py` |
| Reusable agents (one per lifecycle stage) | `.claude/agents/` |
## What HQ is NOT
- Not a place for personal files. Those belong in their own domain repos.
- Not a place for project-specific agents or skills. HQ holds **generic** capabilities that
  work across many repos. Anything that names a particular app, service or dataset lives in
  that project's own repo. See `.claude/agents/README.md`.
- Never store passwords, keys, or secrets anywhere in git.

## Ask the user first before
- Creating GitHub repos, or pushing to GitHub for the first time
- Deleting anything
- Touching real personal data (use a test repo while the system is being built)
