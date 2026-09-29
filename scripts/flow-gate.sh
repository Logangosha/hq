#!/usr/bin/env bash
# The user's decision at a workflow gate (the /review skill, for a `flow:` item).
# Usage: bash scripts/flow-gate.sh <owner/repo> <n>                    — show the gate
#        bash scripts/flow-gate.sh <owner/repo> <n> approve
#        printf '%s' "$COMMENT" | bash scripts/flow-gate.sh <owner/repo> <n> reject
# Show prints workflow=, step=, ask=. Approve posts `/approve`; reject posts the stdin
# text verbatim; both unassign the owner and follow the matching arrow.
# Exit codes: 0 ok. 1 bad usage. 3 not an open flow: item at a gate (prints where it is).
set -euo pipefail

REPO="${1:-}"; NUM="${2:-}"; DECISION="${3:-}"
if [ -z "$REPO" ] || [ -z "$NUM" ]; then
  echo "Usage: bash scripts/flow-gate.sh <owner/repo> <n> [approve|reject]" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/flow-fetch.sh
. "$HERE/scripts/lib/flow-fetch.sh"
# shellcheck source=runner/flow-lib.sh
. "$HERE/scripts/runner/flow-lib.sh"

INFO="$(gh issue view "$NUM" --repo "$REPO" --json state,labels --jq '.state + " " + ([.labels[].name] | join(" "))')"
LABELS="$(tr ' ' '\n' <<<"$INFO")"
WF="$(sed -n 's/^flow://p' <<<"$LABELS" | head -1)"
STEP="$(sed -n 's/^step://p' <<<"$LABELS" | head -1)"
if [ "${INFO%% *}" != OPEN ] || [ -z "$WF" ] || [ -z "$STEP" ]; then
  echo "Not an open workflow item: $INFO"
  exit 3
fi

FILE="$(mktemp)"
trap 'rm -f "$FILE"' EXIT
flow_fetch "$REPO" "$WF" "$FILE" >/dev/null || { echo "No workflow file for $WF."; exit 3; }
IFS=$'\t' read -r KIND _ ASK < <(flow_stage "$FILE" "$STEP" || printf '?\t\t\n')
if [ "$KIND" != gate ]; then
  echo "At step $STEP of $WF — not a gate."
  exit 3
fi

if [ -z "$DECISION" ]; then
  printf 'workflow=%s\nstep=%s\nask=%s\n' "$WF" "$STEP" "$ASK"
  exit 0
fi

case "$DECISION" in
  approve) gh issue comment "$NUM" --repo "$REPO" --body "/approve"; OUTCOME=approved ;;
  reject)  gh issue comment "$NUM" --repo "$REPO" --body-file -; OUTCOME=rejected ;;
  *) echo "Decision must be approve or reject." >&2; exit 1 ;;
esac

gh issue edit "$NUM" --repo "$REPO" --remove-assignee "${REPO%%/*}" >/dev/null 2>&1 || true
flow_move "$REPO" "$NUM" "$FILE" "$STEP" "$OUTCOME"
echo "moved=$OUTCOME"
