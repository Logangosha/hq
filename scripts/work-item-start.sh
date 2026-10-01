#!/usr/bin/env bash
# Start a Work Item the way an agent does: through a view-only Work Item workflow
# (workflows/work-item.md, workflows/small-work-item.md). Same Issue as create-work-item.sh,
# with --small added for small-work-item.
# Usage: bash scripts/work-item-start.sh <owner/repo> <workflow> "Title" "Current" "Desired" [create-work-item args]
# Exit codes: 1 bad usage. 3 no such workflow, or it isn't a Work Item workflow.
# 7 an agent run (HQ_RUN_AGENT set) that doesn't list the workflow in its `workflows:`.
set -euo pipefail

REPO="${1:-}"; WF="${2:-}"
if [ -z "$REPO" ] || [ -z "$WF" ] || [ $# -lt 3 ]; then
  echo "Usage: bash scripts/work-item-start.sh <owner/repo> <workflow> \"Title\" \"Current\" \"Desired\"" >&2
  exit 1
fi
shift 2

if [ -n "${HQ_RUN_AGENT:-}" ] && [[ ",${HQ_RUN_WORKFLOWS:-}," != *",$WF,"* ]]; then
  echo "Workflow $WF isn't on $HQ_RUN_AGENT's list; this run may not start it." >&2
  exit 7
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/flow-fetch.sh
. "$HERE/scripts/lib/flow-fetch.sh"
# shellcheck source=runner/flow-lib.sh
. "$HERE/scripts/runner/flow-lib.sh"

FILE="$(mktemp)"
trap 'rm -f "$FILE"' EXIT
flow_fetch "$REPO" "$WF" "$FILE" >/dev/null || { echo "No workflow named $WF in $REPO or in HQ." >&2; exit 3; }

flow_is_work_item "$WF" || { echo "$WF isn't a Work Item workflow; use scripts/flow-start.sh." >&2; exit 3; }

EXTRA=()
[ "$WF" = small-work-item ] && EXTRA=(--small)
exec bash "$HERE/scripts/create-work-item.sh" "$REPO" "$@" "${EXTRA[@]}"
