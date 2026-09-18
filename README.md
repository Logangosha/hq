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

## How to use

### Set it up (once, on a new computer)

1. **Install the tools:** [git](https://git-scm.com/downloads), the
   [GitHub CLI](https://cli.github.com), and
   [Claude Code](https://claude.com/claude-code).
2. **Copy HQ into your own GitHub account.** On
   [github.com/Logangosha/hq](https://github.com/Logangosha/hq), click **Use this template**
   → **Create a new repository**, name it `hq`, and choose **Public** — your other repos
   fetch the agents from it.
3. **Get it onto your computer.** In [GitHub Desktop](https://desktop.github.com):
   File → Clone repository → your new `hq`.
4. **Open the `hq` folder in Claude Code and type `/setup-hq`.** It walks you through the
   rest: your domain repos, the workflow, the Claude GitHub App and the token. It finishes
   by running a test Work Item.

To see what's set up and what's missing at any time, type `/check-setup`.

### Everyday use

1. Open a Claude Code session on `hq` — desktop, terminal, or the Claude phone app (Code tab).
2. Say what you want and which repo it's for:
   `/new-work-item add opening hours for Sundays in hq-test-sandbox`
3. Walk away. The agents take it through requirements, checks, plan, build and QA, posting
   each step as a comment on the Issue.
4. When it reaches `stage:review`, read the Issue and **merge the PR to approve**, or
   comment what's wrong to send it back.

### Adding a new repo later

Type `/add-domain <repo name>` and say what kind of work goes there. Claude creates the
repo if needed (asking first), registers it, installs the workflow, and walks you through
adding the token on the GitHub website.
