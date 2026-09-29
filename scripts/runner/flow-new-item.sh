#!/usr/bin/env bash
# For a workflow stage that finds things (a job, a recipe idea): opens one item Issue.
# Usage: printf '%s' "$BODY" | bash .hq/scripts/runner/flow-new-item.sh "<title>"
# Prints the Issue URL. The item starts at the stage the workflow's Items table names
# for this stage; flow-route.sh starts its agent once this stage ends.
set -euo pipefail

TITLE="${1:?usage: flow-new-item.sh <title> (body on stdin)}"
: "${GITHUB_REPOSITORY:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"

[ -f "$FLOW_STEP_FILE" ] || { echo "No workflow step is running" >&2; exit 1; }
NUM="$(sed -n 's/^num=//p' "$FLOW_STEP_FILE")"
WF="$(sed -n 's/^wf=//p' "$FLOW_STEP_FILE")"
STAGE="$(sed -n 's/^stage=//p' "$FLOW_STEP_FILE")"
FILE="$(sed -n 's/^file=//p' "$FLOW_STEP_FILE")"

START="$(flow_start_of "$FILE" "$STAGE")"
[ -n "$START" ] || { echo "The workflow's Items table has no row made by $STAGE" >&2; exit 1; }

flow_label "$GITHUB_REPOSITORY" "flow:$WF"
flow_label "$GITHUB_REPOSITORY" "step:$START"

BODY_FILE="$(mktemp)"
{
  cat
  printf '\n\n---\nMade by #%s at `%s`\n' "$NUM" "$STAGE"
} > "$BODY_FILE"

URL="$(gh issue create --repo "$GITHUB_REPOSITORY" --title "$TITLE" \
  --label "flow:$WF" --label "step:$START" --body-file "$BODY_FILE")"
rm -f "$BODY_FILE"

printf '%s\n' "${URL##*/}" >> "$FLOW_MADE_FILE"
printf '%s\n' "$URL"
