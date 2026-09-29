#!/usr/bin/env bash
# After a workflow stage ran: move its item along the arrow for OUTCOME, then start the
# Issues the stage opened. Runs once per dispatch — a second call does nothing.
# Usage: NUM=12 OUTCOME=done GITHUB_REPOSITORY=owner/repo bash .hq/scripts/runner/flow-route.sh
# Needs GH_TOKEN and the state file run-open.sh wrote.
set -euo pipefail

: "${NUM:?}" "${OUTCOME:?}" "${GITHUB_REPOSITORY:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"

[ -f "$FLOW_STEP_FILE" ] || { echo "No workflow step is running" >&2; exit 1; }
[ -f "$FLOW_ROUTED_FILE" ] && exit 0
: > "$FLOW_ROUTED_FILE"

WF="$(sed -n 's/^wf=//p' "$FLOW_STEP_FILE")"
STAGE="$(sed -n 's/^stage=//p' "$FLOW_STEP_FILE")"
FILE="$(sed -n 's/^file=//p' "$FLOW_STEP_FILE")"

FAILED=0
flow_move "$GITHUB_REPOSITORY" "$NUM" "$FILE" "$STAGE" "$OUTCOME" || FAILED=1

if [ -f "$FLOW_MADE_FILE" ]; then
  START="$(flow_start_of "$FILE" "$STAGE")"
  while read -r MADE; do
    [ -n "$MADE" ] || continue
    flow_arrive "$GITHUB_REPOSITORY" "$MADE" "$FILE" "$START" || {
      flow_wait "$GITHUB_REPOSITORY" "$MADE" "🛑 Couldn't start stage \`$START\` (\`$WF\`). Waiting on you."
      FAILED=1
    }
  done < "$FLOW_MADE_FILE"
fi

if [ "$FAILED" -ne 0 ]; then
  flow_wait "$GITHUB_REPOSITORY" "$NUM" "🛑 Couldn't start the next stage after \`$STAGE\` (\`$OUTCOME\`) in \`$WF\`. Waiting on you."
  exit 1
fi
