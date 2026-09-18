# Features Roadmap

We build one small step at a time. Each feature ends with a **user check** before moving on.

The flow we're building toward: **you say it** (F5) → **it becomes an Issue** (F5) →
**GitHub runs it** (F7) → **you're alerted and review** (F8). You appear only at the
first and last step.

---

## Done so far ✅

- **F1 HQ home base** — README, CLAUDE.md, lifecycle, domain registry, private repo.
- **F2 Work Item format** — goal-only Issue body, stage labels, `create-labels.sh`, `hq-test-sandbox`.
- **F3 Test run by hand** — one sandbox Work Item taken through every stage to a merge.
- **F4 Reusable agents** — one agent per stage in `.claude/agents/`; generic ones live in HQ.

## F4 (deferred): workflows that write themselves

- [ ] F4.8 After a few similar Work Items, Claude reads the recorded `Decisions` and offers
      a short overlay (about 15 lines) for the user to approve
- [ ] F4.9 Store approved overlays in `orchestration/workflows/` and use them automatically
- [ ] ✅ User check: read a proposed workflow. Is it 5 lines you agree with?

> Needs several similar Work Items to generalise from. Revisit once there is a real backlog.

## F5: HQ creates work from plain English
*Goal: the user says what they want, and HQ creates the Issue in the right place.*

- [x] F5.1 Write `scripts/create-work-item.sh`: takes a repo, title and goal, creates the
      Issue with the goal as its body, at `stage:requirements`
- [x] F5.2 Write the routing rules (request → domain; no workflow is chosen up front)
- [x] F5.3 `new-work-item` skill: the front door. Takes *"I want X done in Y"*, applies
      `routing.md`, runs the script, replies with one line and the link
- [x] F5.4 Test: a plain request becomes an Issue in `hq-test-sandbox`
- [x] F5.5 Test with 2 more requests (the user always names the repo — no unnamed test)
- [ ] ✅ User check: did each request land in the right repo, with a goal you recognise?

## F6: Setup for a new user
*Goal: anyone can copy HQ onto a fresh computer and get a Work Item running. Nothing personal is hardcoded.*

- [x] F6.1 Make `hq` a template repo, so copying is one `gh repo create --template` command
- [x] F6.2 `scripts/check-setup.sh` — reports what's set up and what's missing
- [x] F6.3 `setup-hq` skill: owner, domains, repos *(asks first)*, workflow, app, token,
      then a test Work Item
- [x] F6.4 README "How to use" section
- [ ] F6.5 Test it from a fresh copy of HQ, on a different account
- [ ] ✅ User check: run the setup yourself. Was it easy?

## F7: GitHub runs it
*Goal: create an Issue, walk away, and the work happens.*

**The trigger is the `stage:` label, not an @-mention.** The label is already the source of
truth for where the work is, so using it as the trigger means state and trigger can never
disagree. An agent that forgets to @ the next one would stall silently with a correct label.

- [x] F7.1 Decide how a domain repo reaches HQ's agents at run time → **HQ is public;
      each domain repo's Action fetches HQ's agents when it runs.** No token, one place to edit.
- [x] F7.2 Install the Claude GitHub App *(user does this, with guidance)*
- [x] F7.3 Add `CLAUDE_CODE_OAUTH_TOKEN` as a repo secret *(user does this, per repo)*
- [x] F7.4 `orchestration/work-item.yml` fires on a `stage:` label change and runs that
      stage's agent; `scripts/enable-agents.sh` installs it in a domain repo
- [x] F7.5 A repo's own `.claude/agents/` overrides HQ's for that repo; HQ's is the fallback
- [x] F7.6 Test: set `stage:requirements`, and the requirements agent writes them
- [x] F7.7 Each stage sets the next label, so the chain runs itself (sandbox #13 ran
      requirements → review unattended; needs `allowed_bots: "claude"`)
- [ ] F7.8 A bounce works: an agent sets the label *backwards* and the right agent picks it up
      *(deferred — test issues #15, #19 in the sandbox)*
- [x] F7.9 Stop and wait when the user is needed (`waiting:*` skips the run), or when a
      stage is reached 3 times (workflow counts that agent's stage comments)
- [ ] ✅ User check: create an Issue from your phone and watch it move

## F8: You're alerted, and you review
*Goal: know when something needs you, without going looking.*

- [ ] F8.1 Reaching `stage:review` notifies you (assign the Issue, so the phone app pings)
- [ ] F8.2 GitHub Project board with a column per stage
- [ ] F8.3 Auto-add Issues from all domain repos
- [ ] F8.4 "Needs my decision" view — `stage:review` and `waiting:user` across every repo
- [ ] F8.5 "How's X going?" summaries from HQ
- [ ] F8.6 `/review <repo>#<n>`: run the PR on your computer, then approve (merge) or reject
      (back to Requirements) — no git by hand
- [ ] ✅ User check: open the board on your phone. Is it clear what needs you?

## F9: Big goals become smaller Work Items
*Goal: a big request becomes a set of connected Work Items.*

- [ ] F9.1 Add parent/child rules to the lifecycle
- [ ] F9.2 Add a "break it down" step to Plan
- [ ] F9.3 When a child finishes, start work that was waiting on it
- [ ] F9.4 A parent is done only when all its children are done
- [ ] F9.5 Test with a small 3-part sandbox project
- [ ] ✅ User check: are the parts and their order clear?

## F10: More workflows
*Goal: the system handles more kinds of work.*

- [ ] F10.1 `software-feature` workflow
- [ ] F10.2 `research` workflow
- [ ] F10.3 `bug-fix` workflow
- [ ] F10.4 Add real domains, once the system is proven
- [ ] ✅ User check: try one real task with each workflow
