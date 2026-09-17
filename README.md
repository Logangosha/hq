# HQ

HQ is the control center for an AI work system.

- The user tells HQ what they want. HQ turns it into a **Work Item** (a GitHub Issue) in the right repo.
- Work is a change from a **current state** to a **desired state**, and it's only done when there's **evidence** it worked.
- Every Work Item goes through these steps:
  1. **Requirements**: what must be true when this is done?
  2. **Verification**: a checklist of tests that prove each requirement was met.
  3. **Plan**: how we'll do it.
  4. **Build**: the builder gets the requirements and plan, and does the work.
  5. **QA**: a separate agent runs the verification checklist.
  6. **Human review**: the user checks it. If it looks good, it's **Done**. If not, it goes back to step 1 with their comments.
- HQ holds the rules and registries. The user's actual files live in their own repos, not here.
