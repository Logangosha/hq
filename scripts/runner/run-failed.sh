#!/usr/bin/env bash
# A manually-dispatched agent step didn't complete (crash, timeout, turn limit), or
# the agent name didn't exist. Nothing else records that on the run Issue.
# Usage: NUM=29 AGENT=builder bash .hq/scripts/runner/run-failed.sh
# Needs GH_TOKEN and GITHUB_REPOSITORY.
set -euo pipefail

: "${NUM:?}" "${AGENT:?}" "${GITHUB_REPOSITORY:?}"

RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"

gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
  "🛑 The **$AGENT** agent run failed to complete (crash, timeout, or hit its turn limit). Run: $RUN_URL"

# A workflow stage that failed still moves its item, by its `failed` arrow.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
if [ -f "$FLOW_STEP_FILE" ]; then
  OUTCOME=failed bash "$HERE/flow-route.sh"
fi
