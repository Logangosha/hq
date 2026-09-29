#!/usr/bin/env bash
# Opens the run Issue for a manual agent dispatch (workflow_dispatch: agent + ask).
# Usage: AGENT=builder ASK='do the thing' GITHUB_REPOSITORY=owner/repo \
#        bash .hq/scripts/runner/run-open.sh
# Needs GH_TOKEN. Writes num=<issue number> to $GITHUB_OUTPUT (stdout when unset).
set -euo pipefail

: "${AGENT:?}" "${ASK:?}" "${GITHUB_REPOSITORY:?}"

# A workflow stage start (`hq-step <n> <stage>`, sent by flow-lib.sh) reuses the item's
# Issue instead of opening one. The state file tells the later steps it is an item.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
rm -f "$FLOW_STEP_FILE" "$FLOW_MADE_FILE" "$FLOW_ROUTED_FILE"
if [[ "$ASK" =~ ^hq-step\ ([0-9]+)\ ([a-z0-9-]+)$ ]]; then
  N="${BASH_REMATCH[1]}"; STAGE="${BASH_REMATCH[2]}"
  LABELS="$(gh issue view "$N" --repo "$GITHUB_REPOSITORY" --json state,labels \
    --jq 'if .state == "OPEN" then [.labels[].name] | join(" ") else "" end')"
  WF="$(tr ' ' '\n' <<<"$LABELS" | sed -n 's/^flow://p' | head -1)"
  if [ -z "$WF" ] || ! grep -qxF "step:$STAGE" <<<"$(tr ' ' '\n' <<<"$LABELS")"; then
    echo "Stale start: #$N is not an open $WF item at step:$STAGE" >&2
    exit 1
  fi
  FILE="$(flow_file "$WF")" || { echo "No workflow file for $WF" >&2; exit 1; }
  printf 'num=%s\nwf=%s\nstage=%s\nagent=%s\nfile=%s\n' "$N" "$WF" "$STAGE" "$AGENT" "$FILE" > "$FLOW_STEP_FILE"
  printf 'num=%s\n' "$N" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  exit 0
fi

TITLE="Run: $AGENT — $(printf '%s' "$ASK" | head -1 | cut -c1-60)"

BODY_FILE="$(mktemp)"
{
  printf 'Agent: %s\n\n' "$AGENT"
  printf 'Ask:\n\n%s\n\n' "$ASK"
  printf -- '---\nStarted from %s/%s/actions/runs/%s\n' "${GITHUB_SERVER_URL:-https://github.com}" "$GITHUB_REPOSITORY" "${GITHUB_RUN_ID:-}"
} > "$BODY_FILE"

URL="$(gh issue create --repo "$GITHUB_REPOSITORY" --title "$TITLE" --label run --body-file "$BODY_FILE")"
rm -f "$BODY_FILE"

NUM="${URL##*/}"
printf 'num=%s\n' "$NUM" >> "${GITHUB_OUTPUT:-/dev/stdout}"
