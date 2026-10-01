#!/usr/bin/env bash
# The owner replied on a run Issue (issue_comment): decide whether that starts the
# agent again, and get the checkout ready. Writes go=false (nothing runs) or go=true,
# num=<issue>, agent=<name> to $GITHUB_OUTPUT (stdout when unset).
# Reads the event from $GITHUB_EVENT_PATH. Needs GH_TOKEN and GITHUB_REPOSITORY.
# The workflow's `if` already filters; this re-checks, since it is cheap and the
# cost of a loop is high.
set -euo pipefail

: "${GITHUB_EVENT_PATH:?}" "${GITHUB_REPOSITORY:?}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"
skip() { echo "Not a reply to run: $1"; echo "go=false" >> "$OUT"; exit 0; }

EV="$GITHUB_EVENT_PATH"
NUM="$(jq -r .issue.number "$EV")"
LABELS="$(jq -r '[.issue.labels[].name] | join(" ")' "$EV")"
[ "$(jq -r '.issue.pull_request // empty' "$EV")" = "" ] || skip "a PR comment"
grep -qw run <<<"$LABELS" || skip "no run label"
grep -qE '(^| )(flow|stage|step):' <<<"$LABELS" && skip "a workflow or Work Item"
[ "$(jq -r .comment.user.login "$EV")" = "$(jq -r .repository.owner.login "$EV")" ] || skip "not the owner"
jq -r .comment.body "$EV" | head -1 | grep -q '^<!-- hq-' && skip "an HQ marker comment"

AGENT="$(jq -r '.issue.body // ""' "$EV" | sed -n 's/^Agent: *//p' | head -1 | tr -d '[:space:]')"
[ -n "$AGENT" ] || skip "no Agent: line"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
rm -f "$FLOW_STEP_FILE" "$FLOW_MADE_FILE" "$FLOW_ROUTED_FILE"

if [ "$(jq -r .issue.state "$EV")" = closed ]; then
  gh issue reopen "$NUM" --repo "$GITHUB_REPOSITORY"
fi

# Build on the run's earlier turns, if they changed files.
BRANCH="run/$NUM-$AGENT"
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git fetch origin "$BRANCH"
  git switch -C "$BRANCH" FETCH_HEAD
fi

printf 'go=true\nnum=%s\nagent=%s\n' "$NUM" "$AGENT" >> "$OUT"
