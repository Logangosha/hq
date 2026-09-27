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

BODY_FILE="$(mktemp)"
printf '%s' "$FINAL" | cut -c1-65000 > "$BODY_FILE"

gh issue comment "$NUM" --repo "${GITHUB_REPOSITORY:?}" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
