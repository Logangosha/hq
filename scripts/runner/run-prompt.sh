#!/usr/bin/env bash
# What a manually-dispatched agent is told when it starts (workflow_dispatch, not a
# Work Item stage). Kept here, not in the workflow, for the same reason as prompt.sh.
# Usage: NUM=29 AGENT=builder ASK='do the thing' bash .hq/scripts/runner/run-prompt.sh
# If AGENT doesn't exist (here or in HQ), comments on the run Issue and exits 1
# without writing a prompt. Otherwise writes text=<the prompt> to $GITHUB_OUTPUT
# (stdout when that isn't set).
set -euo pipefail

: "${NUM:?}" "${AGENT:?}" "${ASK:?}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"

RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:?}/actions/runs/${GITHUB_RUN_ID:-}"

if ! [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || [ ! -f ".claude/agents/$AGENT.md" ]; then
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
    "🛑 No agent named \`$AGENT\` here or in HQ. Run: $RUN_URL"
  [ -f "$FLOW_STEP_FILE" ] && OUTCOME=failed bash "$HERE/flow-route.sh" || true
  exit 1
fi

OUT="${GITHUB_OUTPUT:-/dev/stdout}"

# A workflow stage: the item's Issue is the memory, the agent comments on it.
if [ -f "$FLOW_STEP_FILE" ]; then
  WF="$(sed -n 's/^wf=//p' "$FLOW_STEP_FILE")"
  STAGE="$(sed -n 's/^stage=//p' "$FLOW_STEP_FILE")"
  FILE="$(sed -n 's/^file=//p' "$FLOW_STEP_FILE")"
  OUTCOMES="$(flow_outcomes "$FILE" "$STAGE")"
  MAKES=""
  if [ -n "$(flow_start_of "$FILE" "$STAGE")" ]; then
    MAKES="
4. This stage opens new items. Open each with \`bash .hq/scripts/runner/flow-new-item.sh \"<title>\"\`
   (body on stdin), never \`gh issue create\`."
  fi
  DIGEST="$(bash "$HERE/issue-digest.sh" "$GITHUB_REPOSITORY" "$NUM")"
  BODY="$(printf 'You are the %s agent, running stage `%s` of workflow `%s` on Issue #%s.

1. Read `.claude/agents/%s.md` and do exactly what it says, on this item. The workflow
   is `%s`.
2. Do not touch the Issue'"'"'s labels or close it — the runner moves it.
3. Your final message is posted as your stage comment on #%s. End it with a line
   `Outcome: <outcome>`, where <outcome> is one of: %s (or `failed`). Leave any file
   changes uncommitted.%s

The Issue so far (ask, answers, earlier stages, any rejection comment):

%s' "$AGENT" "$STAGE" "$WF" "$NUM" "$AGENT" "$FILE" "$NUM" "${OUTCOMES:-done}" "$MAKES" "$DIGEST")"
  DELIM="prompt-$(date +%s%N)"
  while grep -qF "$DELIM" <<<"$BODY"; do DELIM="${DELIM}x"; done
  printf 'text<<%s\n%s\n%s\n' "$DELIM" "$BODY" "$DELIM" >> "$OUT"
  exit 0
fi

# A scheduled start: the ask is the one on the run Issue the scheduler opened.
if [[ "$ASK" =~ ^hq-issue\ [0-9]+$ ]]; then
  ASK="$(gh issue view "$NUM" --repo "$GITHUB_REPOSITORY" --json body --jq '
    .body | capture("Ask:\n\n(?<a>(.|\n)*?)(\n\n---\nStarted from|$)").a // ""')"
fi

DELIM="prompt-$(date +%s%N)"
while grep -qF "$DELIM" <<<"$ASK"; do DELIM="${DELIM}x"; done

BODY="$(printf 'You are the %s agent, run once on request — not a Work Item stage.

1. Read `.claude/agents/%s.md` and do exactly what it says, treating the ask below as
   your task.
2. This is run Issue #%s, not a lifecycle Issue: do not touch its labels, do not
   comment on it, and do not follow the Work Item lifecycle.
3. Do not commit or push — when you finish, the runner turns any file changes into a PR and
   links it on this Issue. Say what you changed; never say it was left uncommitted.
4. Your final message is posted as the result, so make it the answer, not a plan.

Ask:

%s' "$AGENT" "$AGENT" "$NUM" "$ASK")"

printf 'text<<%s\n%s\n%s\n' "$DELIM" "$BODY" "$DELIM" >> "$OUT"
