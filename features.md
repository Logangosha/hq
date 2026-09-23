# Features Roadmap — v2

We build one small step at a time. Each feature ends with a **user check** before moving on.

v1 (F1–F8: HQ, Work Items, the GitHub runner, the review dashboard) is in
`archive/features-v1.md`. Its open items are carried below with their IDs kept.

Where v2 is heading:
- **Goals** — say something big; HQ breaks it into Work Items, runs them in order, and
  tells you when the whole thing is done.
- **Agents** — set up agents for other kinds of work (email, personal finance, research)
  that run on a schedule or on request, not only through the build lifecycle.

---

## Carried over from v1

- [ ] F5 ✅ User check: did each request land in the right repo, with a goal you recognise?
- [ ] F6.5 Test setup from a fresh copy of HQ, on a different account
- [ ] F6 ✅ User check: run the setup yourself. Was it easy?
- [ ] F7.10 Let the agents look things up: allow `WebSearch` and `WebFetch` in the runner
- [ ] F7.8 A bounce works: an agent sets the label *backwards* and the right agent picks
      it up *(test issues #15, #19 in the sandbox)*
- [ ] F7 ✅ User check: create an Issue from your phone and watch it move
- [ ] F8.9 The dashboard refreshes itself *(in flight — hq#26)*
- [ ] F8.2 `work-items` flags what needs you (`stage:review`, `waiting:user`)
- [ ] F8.7 "How's X going?" — a one-line status per item on the dashboard
- [ ] F8 ✅ User check: notification → dashboard → review → decision, without touching git
- [ ] F4.8–F4.9 Workflows that write themselves, from recorded `Decisions` *(waits for a
      real backlog)*

## F9: Goals — big requests become connected Work Items
*Goal: say something big once; HQ splits it, runs the parts in order, and closes it when
every part is done.*

A **Goal** is a parent Issue (`type:goal`). Its parts are ordinary Work Items, linked as
GitHub sub-issues. A part that must wait for another carries `waiting:work`.
*Judgment call: a Goal lives in its domain repo, or in HQ when it spans repos.*

- [ ] F9.1 Goal format: `type:goal` label, body = outcome + parts table (part, repo,
      depends on). Add parent/child rules to `orchestration/lifecycle.md`
- [ ] F9.2 `new-goal` skill: plain request → proposed breakdown → you approve the list →
      Goal and parts are created, linked, and ordered
- [ ] F9.3 Planner can say "too big": it proposes a breakdown on the Issue instead of a
      plan, and the item becomes a Goal once you approve
- [ ] F9.4 Unblock: when a part reaches Done, remove `waiting:work` from parts whose
      blockers are all closed (runner script, not the workflow)
- [ ] F9.5 A Goal closes only when every part is closed; then it goes to you for a
      final review of the whole
- [ ] F9.6 Cross-repo parts: decide how a run opens Issues in another repo (GitHub App
      token vs. a secret per repo) and weigh what a wrong agent could then reach
- [ ] F9.7 Dashboard shows each Goal with its parts and progress (e.g. 2 of 5 done)
- [ ] F9.8 Test with a 3-part sandbox Goal, one part waiting on another
- [ ] ✅ User check: are the parts and their order clear? Did it finish without you
      pushing it along?

## F10: Agents — set up agents and workflows for any kind of work
*Goal: say "I want an email agent" or "a personal finance agent", and HQ sets one up in
its own domain repo — safely, and reporting back to you.*

Two kinds of agent:
- **Lifecycle agents** — work through Work Items (today's builder, QA, etc.).
- **Standing agents** — run on a schedule or trigger (e.g. triage email each morning,
  summarise spending each month) and report to you.

Project-specific agents live in their domain repo, never in HQ. HQ holds only the
generic parts: the format, the setup skill, and the runner.

- [ ] F10.1 Agent format: one file per agent = job, trigger (schedule / label / request),
      tools and data it may use, what it may **never** do alone, and where it reports
- [ ] F10.2 Safety defaults: read-only first; anything outward (send, pay, delete) is a
      draft that waits for you (`waiting:user`). Secrets only in GitHub secrets
- [ ] F10.3 Standing-agent runner: a scheduled workflow stub (installed like
      `work-item.yml`), logic in `scripts/runner/`
- [ ] F10.4 Reports: each run posts a short digest to a pinned Issue in its domain; items
      that need you appear on the dashboard
- [ ] F10.5 `new-agent` skill: plain request → agent file + trigger + secrets checklist,
      delivered as a Work Item in the domain repo so it goes through QA and your review
- [ ] F10.6 Connecting data: how an agent reaches Gmail, a bank export, etc. Pick one
      approach per source; least access that works
- [ ] F10.7 First real agent — **email**: morning triage, labels and a digest, replies
      drafted not sent. Try on a test inbox first
- [ ] F10.8 Second real agent — **personal finance**: monthly spending summary from an
      export, read-only
- [ ] F10.9 Lifecycle workflows for more kinds of Work Item: `software-feature`,
      `research`, `bug-fix`
- [ ] ✅ User check: set up an agent by asking for it. Did it do its job without doing
      anything you didn't approve?
