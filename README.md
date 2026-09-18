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
   [GitHub CLI](https://cli.github.com) (then run `gh auth login`), and
   [Claude Code](https://claude.com/claude-code).
2. **Copy HQ into your own GitHub account.** It must stay **public** — your other repos
   fetch the agents from it.
   ```bash
   gh repo create <your-github-name>/hq --public --template Logangosha/hq --clone
   ```
3. **Open the `hq` folder in Claude Code and type `/setup-hq`.** It walks you through the
   rest: your domain repos, the workflow, the Claude GitHub App and the token. It finishes
   by running a test Work Item.

To see what's set up and what's missing at any time: `bash scripts/check-setup.sh`

### Everyday use

1. Open a Claude Code session on `hq` — desktop, terminal, or the Claude phone app (Code tab).
2. Say what you want and which repo it's for:
   `/new-work-item add opening hours for Sundays in hq-test-sandbox`
3. Walk away. The agents take it through requirements, checks, plan, build and QA, posting
   each step as a comment on the Issue.
4. When it reaches `stage:review`, read the Issue and **merge the PR to approve**, or
   comment what's wrong to send it back.

### Adding a new repo later

Add a row to `registry/domains.md`, then:

```bash
bash scripts/enable-agents.sh <owner>/<repo>
```

and add the token secret to it (`/setup-hq` shows the exact command).
