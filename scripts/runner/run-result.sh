#!/usr/bin/env bash
# Posts a manually-dispatched agent's final message as a comment on its run Issue.
# Usage: NUM=29 EXECUTION_FILE=/path/to/execution.json bash .hq/scripts/runner/run-result.sh
# EXECUTION_FILE is claude-code-action's run log; it may be missing, empty or unreadable.
set -euo pipefail

: "${NUM:?}"

FINAL=""
if [ -n "${EXECUTION_FILE:-}" ] && [ -s "$EXECUTION_FILE" ] && jq -e . "$EXECUTION_FILE" >/dev/null 2>&1; then
  RESULT="$(jq -c '[.[] | select(.type == "result")] | last' "$EXECUTION_FILE" 2>/dev/null)" || RESULT=""
  if [ -n "$RESULT" ] && [ "$RESULT" != "null" ]; then
    FINAL="$(jq -r '.result // empty | strings' <<<"$RESULT" 2>/dev/null)" || FINAL=""
  fi
fi

if [ -z "$FINAL" ]; then
  FINAL="(No final message — the execution file was missing, empty, unreadable or had no result.)"
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"

BODY_FILE="$(mktemp)"
if [ -f "$FLOW_STEP_FILE" ]; then
  # A workflow stage: head the comment, then move the item by the outcome it ends with.
  { printf '**`%s`** — %s agent\n\n' "$(sed -n 's/^stage=//p' "$FLOW_STEP_FILE")" "$(sed -n 's/^agent=//p' "$FLOW_STEP_FILE")"
    printf '%s' "$FINAL" | cut -c1-65000; } > "$BODY_FILE"
else
  printf '%s' "$FINAL" | cut -c1-65000 > "$BODY_FILE"
fi

gh issue comment "$NUM" --repo "${GITHUB_REPOSITORY:?}" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"

if [ -f "$FLOW_STEP_FILE" ]; then
  OUTCOME="$(flow_outcome <<<"$FINAL")" bash "$HERE/flow-route.sh"
fi
