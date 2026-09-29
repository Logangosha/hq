#!/usr/bin/env bash
# Start a workflow run (the /run skill's stage 5, for a workflow). Ask text on stdin.
# Usage: printf '%s' "$ASK" | bash scripts/flow-start.sh <owner/repo> <workflow>
# Opens the run's Issue (flow:<wf>, step:<start>), then starts its first stage.
# Prints issue=<url>.
# Exit codes: 0 ok. 1 bad usage. 3 no such workflow. 6 the workflow has no `trigger` item.
set -euo pipefail

REPO="${1:-}"; WF="${2:-}"
if [ -z "$REPO" ] || [ -z "$WF" ]; then
  echo "Usage: printf '%s' \"\$ASK\" | bash scripts/flow-start.sh <owner/repo> <workflow>" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/flow-fetch.sh
. "$HERE/scripts/lib/flow-fetch.sh"
# shellcheck source=runner/flow-lib.sh
. "$HERE/scripts/runner/flow-lib.sh"

ASK="$(cat; printf x)"; ASK="${ASK%x}"

FILE="$(mktemp)"
trap 'rm -f "$FILE"' EXIT
flow_fetch "$REPO" "$WF" "$FILE" >/dev/null || { echo "No workflow named $WF in $REPO or in HQ." >&2; exit 3; }

START="$(flow_start_of "$FILE" trigger)"
[ -n "$START" ] || { echo "Workflow $WF has no Items row made by trigger." >&2; exit 6; }

flow_label "$REPO" "flow:$WF"
flow_label "$REPO" "step:$START"

BODY_FILE="$(mktemp)"
printf 'Workflow: %s\n\nAsk:\n\n%s\n' "$WF" "$ASK" > "$BODY_FILE"
URL="$(gh issue create --repo "$REPO" \
  --title "$WF: $(printf '%s' "$ASK" | head -1 | cut -c1-60)" \
  --label "flow:$WF" --label "step:$START" --body-file "$BODY_FILE")"
rm -f "$BODY_FILE"

flow_arrive "$REPO" "${URL##*/}" "$FILE" "$START"
echo "issue=$URL"
