# Features Roadmap

We build one small step at a time. Each feature ends with a **user check** before moving on.

---

## F1: HQ home base ✅
*Goal: any Claude session can open HQ and understand the system.*

- [x] F1.1 Create the `hq` folder
- [x] F1.2 Add `README.md` (what HQ is)
- [x] F1.3 Add `CLAUDE.md` (instructions for Claude)
- [x] F1.4 Add `orchestration/lifecycle.md` (stages and rules)
- [x] F1.5 Add `registry/domains.md` (list of domain repos)
- [x] F1.6 Create the private GitHub repo and push
- [x] F1.7 Add `features.md` (this roadmap)
- [ ] ✅ User check: read the README on GitHub

## F2: Work Item template
*Goal: every Work Item looks the same, and HQ can create one in any domain repo.*

- [x] F2.1 Write the Issue template (Goal, Requirements, Verification, Plan, Result)
- [x] F2.2 Define the labels (stage, waiting, domain, workflow)
- [x] F2.3 Add the template to the repo
- [x] F2.4 Write a script that creates the labels in a repo
- [x] F2.5 Create the `hq-test-sandbox` repo
- [x] F2.6 From an HQ session, create a test Issue in `hq-test-sandbox`
- [ ] ✅ User check: open the test Issue. Is it easy to read?

## F3: Test run by hand (in the sandbox)
*Goal: prove the lifecycle works, using fake content only.*

- [x] F3.1 Add some fake starter content to `hq-test-sandbox`
- [x] F3.2 Create the Work Item Issue (no workflow file — the framework is enough)
- [ ] F3.3 Requirements: Claude writes them
- [ ] F3.4 Verification: Claude writes the checklist
- [ ] F3.5 **User approves requirements and checklist** (blueprint inspection)
- [ ] F3.6 Plan
- [ ] F3.7 Build: Claude makes the change in a PR
- [ ] F3.8 QA: a separate agent runs the checklist and posts evidence
- [ ] F3.9 **Human review: user approves and merges** (taste test)
- [ ] F3.10 Claude records on the Issue any judgment calls it had to make
- [ ] ✅ User check: read the Issue top to bottom. Is it clear what happened?

## F4: Reusable agents, and workflows that write themselves
*Goal: agent roles are defined once, and repeated lessons become reusable rules the user only has to approve.*

- [ ] F4.1 Decide where capabilities live (own repo or inside HQ) *(ask first)*
- [ ] F4.2 Write the requirements agent
- [ ] F4.3 Write the QA agent
- [ ] F4.4 Write the planner agent
- [ ] F4.5 Write the builder agent
- [ ] F4.6 Record in HQ where capabilities live
- [ ] F4.7 Re-run a small sandbox Work Item using these agents
- [ ] F4.8 Add the "propose a workflow" step: after a few similar Work Items, Claude reads the judgment calls it recorded and offers a short overlay (about 15 lines) for the user to approve
- [ ] F4.9 Store approved overlays in `orchestration/workflows/` and use them automatically
- [ ] ✅ User check: read a proposed workflow. Is it 5 lines you agree with?

## F5: HQ creates work from plain English
*Goal: the user says what they want, and HQ creates the Issue in the right place.*

- [ ] F5.1 Write `scripts/create-work-item.sh`: takes a repo, title and goal, builds the body from the template, creates the Issue, and adds the `stage:` and `domain:` labels (creating any label that's missing)
- [ ] F5.2 Write the routing rules (request → domain + workflow)
- [ ] F5.3 Add a "new Work Item" instruction to `CLAUDE.md` that uses the script
- [ ] F5.4 Test: a plain request becomes an Issue in `hq-test-sandbox`
- [ ] F5.5 Test with 2 more sandbox requests
- [ ] ✅ User check: did each request land in the right place, with the right workflow?

## F6: Setup skill
*Goal: anyone can copy HQ and set it up for themselves. Nothing personal is hardcoded.*

- [ ] F6.1 `setup-hq` skill asks for the GitHub owner and domains
- [ ] F6.2 It fills in `registry/domains.md`
- [ ] F6.3 It creates any missing repos *(asks first)*
- [ ] F6.4 Test it from a fresh copy of HQ
- [ ] ✅ User check: run the setup yourself. Was it easy?

## F7: Automatic execution (GitHub triggers Claude)
*Goal: create an Issue, walk away, and the work happens.*

- [ ] F7.1 Install the Claude GitHub App *(user does this, with guidance)*
- [ ] F7.2 Add the API key as a repo secret *(user does this)*
- [ ] F7.3 Add a GitHub Action that runs when a stage label changes
- [ ] F7.4 Test: set the Requirements stage, and Claude writes them
- [ ] F7.5 Each stage hands off to the next automatically
- [ ] F7.6 Stop and wait when the user is needed
- [ ] F7.7 Stop after 3 failed QA runs
- [ ] ✅ User check: create an Issue from your phone and watch it move

## F8: Status view
*Goal: see everything at a glance, from any device.*

- [ ] F8.1 GitHub Project board with a column per stage
- [ ] F8.2 Auto-add Issues from all domain repos
- [ ] F8.3 "Needs my decision" view
- [ ] F8.4 "How's X going?" summaries from HQ
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
