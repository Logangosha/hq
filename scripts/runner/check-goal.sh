#!/usr/bin/env bash
# Goal completeness check (R5-R7), run before the requirements or scope agent
# starts. An Issue can reach stage:requirements or stage:scope with an incomplete
# body (edited by hand, or created outside create-work-item.sh's own check), so
# the runner checks again.
# Usage: NUM=29 bash .hq/scripts/runner/check-goal.sh
# Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
# Exit 1 and parks the Work Item if the goal is missing its current/desired state.
set -euo pipefail

: "${NUM:?}" "${GH_TOKEN:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_REPOSITORY_OWNER:?}"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/lib/goal-check.sh"

BODY="$(gh issue view "$NUM" --repo "$GITHUB_REPOSITORY" --json body --jq .body)"
MISSING="$(printf '%s\n' "$BODY" | goal_missing_parts)"

if [ -z "$MISSING" ]; then
  exit 0
fi

WHAT="$(printf '%s' "$MISSING" | goal_join_missing)"
gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
  "🛑 Goal is incomplete: missing $WHAT. Edit the Issue body to add it, then restart it (dashboard Answer button, or remove and re-add its \`stage:\` label)."
# GITHUB_TOKEN label changes don't trigger workflows, so assign here too (same
# idiom as three-strikes.sh).
gh issue edit "$NUM" --repo "$GITHUB_REPOSITORY" --add-label waiting:user \
  --add-assignee "$GITHUB_REPOSITORY_OWNER"
exit 1
