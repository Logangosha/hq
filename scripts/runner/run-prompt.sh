#!/usr/bin/env bash
# What a manually-dispatched agent is told when it starts (workflow_dispatch, not a
# Work Item stage). Kept here, not in the workflow, for the same reason as prompt.sh.
# Usage: NUM=29 AGENT=builder ASK='do the thing' bash .hq/scripts/runner/run-prompt.sh
# If AGENT doesn't exist (here or in HQ), comments on the run Issue and exits 1
# without writing a prompt. Otherwise writes text=<the prompt> to $GITHUB_OUTPUT
# (stdout when that isn't set).
set -euo pipefail

: "${NUM:?}" "${AGENT:?}" "${ASK:?}"

RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:?}/actions/runs/${GITHUB_RUN_ID:-}"

if ! [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || [ ! -f ".claude/agents/$AGENT.md" ]; then
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
    "🛑 No agent named \`$AGENT\` here or in HQ. Run: $RUN_URL"
  exit 1
fi

DELIM="prompt-$(date +%s%N)"
while grep -qF "$DELIM" <<<"$ASK"; do DELIM="${DELIM}x"; done

BODY="$(printf 'You are the %s agent, run once on request — not a Work Item stage.

1. Read `.claude/agents/%s.md` and do exactly what it says, treating the ask below as
   your task.
2. This is run Issue #%s, not a lifecycle Issue: do not touch its labels, do not
   comment on it, and do not follow the Work Item lifecycle.
3. Leave any file changes uncommitted — the runner turns them into a PR itself.
4. Your final message is posted as the result, so make it the answer, not a plan.

Ask:

%s' "$AGENT" "$AGENT" "$NUM" "$ASK")"

OUT="${GITHUB_OUTPUT:-/dev/stdout}"
printf 'text<<%s\n%s\n%s\n' "$DELIM" "$BODY" "$DELIM" >> "$OUT"
