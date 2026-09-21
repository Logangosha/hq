# Features Roadmap

We build one small step at a time. Each feature ends with a **user check** before moving on.

The flow we're building toward: **you say it** (F5) → **it becomes an Issue** (F5) →
**GitHub runs it** (F7) → **you're alerted and review** (F8). You appear only at the
first and last step.

From your phone or computer:
1. `new-work-item` — say what you want and in which repo. It becomes an Issue.
2. The agents run the chain on GitHub and stop at `stage:review`.
3. You get a notification.
4. Open the review dashboard (or `work-items`) and pick the item.
5. Click **Review**. Claude checks out the branch locally and shows you the changes and the app.
6. Leave a comment, then **Approve** (merge and close) or **Reject** (back to the agents with your comment).

Each section lists what's **done** (one line each, IDs kept), then what's **next**, in the
order it should happen.

---

## Done so far ✅

- **F1 HQ home base** — README, CLAUDE.md, lifecycle, domain registry, private repo.
- **F2 Work Item format** — goal-only Issue body, stage labels, `create-labels.sh`, `hq-test-sandbox`.
- **F3 Test run by hand** — one sandbox Work Item taken through every stage to a merge.
- **F4 Reusable agents** — one agent per stage in `.claude/agents/`; generic ones live in HQ.

## F5: HQ creates work from plain English
*Goal: the user says what they want, and HQ creates the Issue in the right place.*

Done: **F5.1** `create-work-item.sh` · **F5.2** routing rules (`registry/routing.md`) ·
**F5.3** `new-work-item` skill · **F5.4–F5.5** three plain requests became Issues
*(the user always names the repo, so there's no unnamed-repo test)*.

- [ ] ✅ User check: did each request land in the right repo, with a goal you recognise?

## F6: Setup for a new user
*Goal: anyone can copy HQ onto a fresh computer and get a Work Item running. Nothing personal is hardcoded.*

Done: **F6.1** HQ is a template repo · **F6.2** `check-setup.sh` · **F6.3** `setup-hq`
skill (owner, domains, repos, workflow, app, token, test Work Item) · **F6.4** README
"How to use".

- [ ] F6.5 Test it from a fresh copy of HQ, on a different account
- [ ] ✅ User check: run the setup yourself. Was it easy?

## F7: GitHub runs it
*Goal: create an Issue, walk away, and the work happens.*

**The trigger is the `stage:` label, not an @-mention.** The label is already the source of
truth for where the work is, so using it as the trigger means state and trigger can never
disagree. An agent that forgets to @ the next one would stall silently with a correct label.

Done: **F7.1** HQ is public, so a domain's Action fetches HQ's agents at run time (no
token) · **F7.2** Claude GitHub App installed · **F7.3** `CLAUDE_CODE_OAUTH_TOKEN` per
repo · **F7.4** `work-item.yml` fires on a `stage:` label and runs that stage's agent
(`enable-agents.sh` installs it) · **F7.5** a repo's own `.claude/agents/` wins, HQ's is
the fallback · **F7.6** requirements agent ran from a label · **F7.7** the chain runs
itself (sandbox #13, requirements → review unattended; needs `allowed_bots: "claude"`) ·
**F7.9** stop and wait when the user is needed (`waiting:*`), or when a stage is reached
3 times.

- [ ] F7.10 Let the agents look things up: allow `WebSearch` and `WebFetch` in the runner
      (today only Bash `curl` reaches the network, so they work from memory). Fixes the
      mismatch where `builder.md` claims WebFetch but the runner doesn't allow it
- [ ] F7.8 A bounce works: an agent sets the label *backwards* and the right agent picks it
      up *(deferred — test issues #15, #19 in the sandbox)*
- [ ] ✅ User check: create an Issue from your phone and watch it move

## F8: You're alerted, and you review
*Goal: know when something needs you, without going looking.*

Done: **F8.1** reaching `stage:review` assigns the Issue and notifies you *(email arrives;
phone push not received)* · **F8.3** `/review <repo>#<n>` in chat *(built, never used — the
dashboard replaced it. Keep for chat-only use, or retire it)* · **F8.4** review dashboard
listing every Work Item that needs you, across all domains · **F8.5** **Review** button:
checkout, the app, and the PR's code changes · **F8.6** **Approve** / **Reject** with a
comment *(Reject proven on hq#21, Approve by merging PR #20)* · **F8.8** **Answer** button
restarts a stopped Work Item · **F8.10** **Drop it** (`drop-work-item.sh`, `--erase`) ·
**F8.11** HQ Work Items are reviewed in a separate copy under `.hq-reviews/`, so a review
can't move the work you're doing in HQ *(proven on hq#23)*.

- [ ] F8.9 The dashboard refreshes itself: every 30s normally, every 5s while an agent is
      working on something. Holds still while you're mid-review or mid-answer
      *(in flight — hq#26)*
- [ ] F8.2 `work-items` flags what needs you — `stage:review` and `waiting:user` — so you
      can find an item without its number
- [ ] F8.7 "How's X going?" — a one-line status for each item on the dashboard
- [ ] ✅ User check: take one Work Item from notification → dashboard → review → decision
      without touching git. Was it clean?

## F4 (deferred): workflows that write themselves

Needs several similar Work Items to generalise from. Revisit once there's a real backlog.

- [ ] F4.8 After a few similar Work Items, Claude reads the recorded `Decisions` and offers
      a short overlay (about 15 lines) for the user to approve
- [ ] F4.9 Store approved overlays in `orchestration/workflows/` and use them automatically
- [ ] ✅ User check: read a proposed workflow. Is it 5 lines you agree with?

## F9: Big goals become smaller Work Items
*Goal: a big request becomes a set of connected Work Items.*

- [ ] F9.1 Add parent/child rules to the lifecycle
- [ ] F9.2 Add a "break it down" step to Plan
- [ ] F9.3 When a child finishes, start work that was waiting on it
- [ ] F9.4 A parent is done only when all its children are done
- [ ] F9.5 Cross-repo Work Items: the run's token is scoped to its own repo, so an agent
      can't open an Issue elsewhere. Decide how (GitHub App token vs. a secret per repo)
      and weigh it — it widens what a wrong agent can reach
- [ ] F9.6 Test with a small 3-part sandbox project
- [ ] ✅ User check: are the parts and their order clear?

## F10: More workflows
*Goal: the system handles more kinds of work.*

- [ ] F10.1 `software-feature` workflow
- [ ] F10.2 `research` workflow
- [ ] F10.3 `bug-fix` workflow
- [ ] F10.4 Add real domains, once the system is proven
- [ ] ✅ User check: try one real task with each workflow
