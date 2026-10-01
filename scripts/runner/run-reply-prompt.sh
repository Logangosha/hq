#!/usr/bin/env bash
# What an agent is told when the owner replies on its run Issue: the ask and the whole
# thread so far, oldest first.
# Usage: NUM=29 AGENT=researcher bash .hq/scripts/runner/run-reply-prompt.sh
# Needs GH_TOKEN and GITHUB_REPOSITORY. If AGENT doesn't exist, comments on the Issue
# and exits 1. Otherwise writes text=<the prompt> to $GITHUB_OUTPUT (stdout when unset).
set -euo pipefail

: "${NUM:?}" "${AGENT:?}" "${GITHUB_REPOSITORY:?}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"

if ! [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || [ ! -f ".claude/agents/$AGENT.md" ]; then
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
    "🛑 No agent named \`$AGENT\` here or in HQ. Run: $RUN_URL"
  exit 1
fi

OWNER="${GITHUB_REPOSITORY%%/*}"
THREAD="$(gh issue view "$NUM" --repo "$GITHUB_REPOSITORY" --json body,comments | jq -r --arg owner "$OWNER" '
  (.body | capture("Ask:\n\n(?<a>(.|\n)*?)(\n\n---\nStarted from|$)").a // "") as $ask
  | "### Ask\n\n" + $ask
    + ([.comments[]
        | select((.body | startswith("<!-- hq-run") or startswith("<!-- hq-stopped")) | not)
        | "\n\n### " + (if .author.login == $owner then "Owner" else "Agent" end) + " · " + .createdAt + "\n\n" + .body]
       | join(""))')"

BODY="$(printf 'You are the %s agent, in a conversation on run Issue #%s. The owner has just replied.

1. Read `.claude/agents/%s.md` and do exactly what it says.
2. This is a run Issue, not a lifecycle Issue: do not touch its labels, do not comment
   on it, and do not follow the Work Item lifecycle.
3. Do not commit or push — the runner turns any file changes into a PR and links it on
   this Issue. Earlier changes are already on your branch. Say what you changed.
4. Your final message is posted as your next reply, so make it the answer, not a plan.
   Answer the owner'"'"'s latest message, using the thread for context.

The thread so far (oldest first):

%s' "$AGENT" "$NUM" "$AGENT" "$THREAD")"

DELIM="prompt-$(date +%s%N)"
while grep -qF "$DELIM" <<<"$BODY"; do DELIM="${DELIM}x"; done
printf 'text<<%s\n%s\n%s\n' "$DELIM" "$BODY" "$DELIM" >> "${GITHUB_OUTPUT:-/dev/stdout}"
