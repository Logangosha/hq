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

## Skills and agents

**Skills are what you type.** Use them in a Claude Code session on `hq`.

| Skill | What it does |
|---|---|
| `/new-work-item` | Turns what you want into a Work Item in the repo you name. Everyday use. |
| `/setup-hq` | First-time setup on a new account: repos, workflow, Claude app, token, test run. |
| `/add-domain` | Lets HQ start working in another repo. |
| `/review` | Runs a finished Work Item on your computer, then approves or rejects it. |
| `/domains` | Lists the repos HQ can send work to. |
| `/repos` | Lists all your GitHub repos: which are domains, which are on this computer. |
| `/remove-domain` | Stops HQ working in a repo. The repo and its Issues stay. |
| `/check-setup` | Checks that everything is connected, and fixes what it can. |

**Agents do the work.** You never call them. Each one runs on GitHub when a Work Item
reaches its stage, does its part, and hands off to the next one.

| Agent | Stage | What it does |
|---|---|---|
| `requirements` | 1 | Writes what must be true when the work is done (R1, R2, …) |
| `verification` | 2 | Checks the requirements, then writes a pass/fail check for each (V1, V2, …) |
| `planner` | 3 | Checks stages 1–2, then writes the plan |
| `builder` | 4 | Checks the plan, then does the work in a PR |
| `qa` | 5 | Runs every check and posts the evidence. It never fixes anything itself. |

Each agent checks the stage before it and can send the work back if something's wrong.
Skills live in `.claude/skills/`, agents in `.claude/agents/`.

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
   `/new-work-item add opening hours for Sundays in my-website`
3. Walk away. The agents take it through requirements, checks, plan, build and QA, posting
   each step as a comment on the Issue.
4. When it reaches `stage:review`, type `/review my-website#12`. Claude switches your copy
   of the repo to the PR, starts the app and shows it to you with the QA results.
   Say **approve** to merge it, or say what's wrong to send it back to Requirements.
   Claude handles all the git, and puts your copy back on `main` afterwards.

### Adding or removing a repo

Type `/repos` to see what you could add. Then `/add-domain <repo name>` and say what kind
of work goes there. Claude creates the repo if needed (asking first), installs the
workflow, and walks you through adding the token on the GitHub website.

`/remove-domain <repo name>` takes a repo off the list without touching its contents.
