#!/usr/bin/env bash
# Drop a Work Item you no longer want: its open PR is closed and its branch deleted,
# then the Issue is closed as "not planned". Nothing is merged.
# Usage: bash scripts/drop-work-item.sh <repo> <issue-number> [reason]
#        bash scripts/drop-work-item.sh <repo> <issue-number> [reason] --erase
#
# --erase also deletes the Issue itself. That is permanent and loses the record of
# what was decided, so the default is to close it, which can be undone.
set -euo pipefail

REPO_NAME="${1:-}"; NUM="${2:-}"; REASON="${3:-}"
ERASE=""
for a in "$@"; do [ "$a" = "--erase" ] && ERASE=1; done
[ "$REASON" = "--erase" ] && REASON=""

if [ -z "$REPO_NAME" ] || [ -z "$NUM" ]; then
  echo "Usage: bash scripts/drop-work-item.sh <repo> <issue-number> [reason] [--erase]" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)"
REPO="$OWNER/$REPO_NAME"

gh issue view "$NUM" --repo "$REPO" --json number >/dev/null || exit 2

# Every open PR that says it closes this Issue goes too, branch and all.
for N in $(gh issue view "$NUM" --repo "$REPO" --json closedByPullRequestsReferences \
             --jq '.closedByPullRequestsReferences[].number' 2>/dev/null); do
  [ "$(gh pr view "$N" --repo "$REPO" --json state --jq .state)" = OPEN ] || continue
  gh pr close "$N" --repo "$REPO" --delete-branch \
    --comment "Dropped with Work Item #$NUM — not wanted." >/dev/null
  echo "closed_pr=$N"
done

BODY="## Dropped — user

Not wanted. Nothing was merged."
[ -n "$REASON" ] && BODY="## Dropped — user

$REASON"
gh issue comment "$NUM" --repo "$REPO" --body "$BODY" >/dev/null

if [ -n "$ERASE" ]; then
  gh issue delete "$NUM" --repo "$REPO" --yes >/dev/null
  echo "erased=$NUM"
else
  gh issue close "$NUM" --repo "$REPO" --reason "not planned" >/dev/null
  echo "closed_issue=$NUM"
fi
