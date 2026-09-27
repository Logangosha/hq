---
name: run
description: Start an agent on GitHub for a one-off ask, outside the Work Item lifecycle. Use for "/run <agent> in <repo>: <ask>" (the ": <ask>" part is optional). Never the built-in "run" skill (launching/screenshotting an app) — this one dispatches a GitHub Actions run.
---

# Run an agent on request

Starts a named agent as a one-off GitHub Actions run (`workflow_dispatch`), not a Work
Item. It never lets a run start while anything required is missing or unclear — asking
again and again is cheaper than a run with the wrong inputs.

## 1. Parse

`/run <agent> in <repo>: <ask>` — `<ask>` and its leading `:` are optional.

- No `<agent>` → ask for the agent name. Name it as missing, don't guess.
- No `<repo>` (no `in <repo>` at all) → ask for the repo. Name it as missing.
- `<repo>` is `owner/repo` or a bare name (owner = this HQ's owner, same as every other
  skill).
- Everything after `:` (verbatim, including punctuation and line breaks) is the ask. No
  `:` → no ask yet; it may still turn out unneeded (see step 5).

## 2. Check

```bash
bash scripts/run-check.sh <repo> <agent>
```

- Exit 4 → the repo has no Work Item workflow with a manual trigger. Say so in one line
  and stop. Nothing is asked, nothing is dispatched.
- Exit 3 → `<agent>` isn't in `<repo>` or in HQ. Say so and ask for another agent name.
- Exit 0 → prints `repo=`, the agent file's contents, and `source=repo|hq`. Carry the
  agent file text into step 3.

## 3. Needs

Read the agent file's **Inputs** section (the standard in
`.claude/agents/README.md`).

- A detail marked **required** → required.
- A detail with a **default** → never asked; use the default silently if unanswered.
- **No Inputs section at all** (e.g. HQ's own agents, which only have a plain
  `**Input:**` line marking nothing) → the only required thing is the ask itself.

Required so far = every required detail, plus the ask if step 3 says it's required and
step 1 didn't get one.

## 4. Ask loop

If anything from step 3 is missing or unclear, send **one** message naming exactly what's
missing (agent, repo, or each unclear/missing detail by name) and wait.

After every answer, re-run step 3's check against the fuller picture. Repeat this whole
step until nothing required is missing or unclear. **Do not go to step 5 from anywhere
else** — it is only reached once this loop ends clean.

## 5. Start

Build the ask to send:

- The user's ask, verbatim, if they gave one.
- Otherwise, if nothing was required: `No ask given — use your defaults.`
- Then, one line per answered detail: `Answers:` followed by `- <detail>: <answer>` for
  each (skip this block if there were none).

```bash
printf '%s' "$ASK_TEXT" | bash scripts/run-start.sh <owner/repo> <agent>
```

## 6. Reply

- Exit 0 → prints `issue=<url>`. Reply with just that link.
- Exit 5 → prints `run=<url>` (no `issue=`). Reply with the Actions run link and say the
  run Issue wasn't found yet.

Nothing else — no recap of the ask, they can open the link.
