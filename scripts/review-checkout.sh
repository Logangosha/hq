#!/usr/bin/env bash
# Put a local copy of a domain repo on a Work Item's PR branch, ready to look at.
# Usage: bash scripts/review-checkout.sh <repo> <issue-number>
#
# Never uses HQ's own folder — that's where Claude works, and checking a PR branch out
# there has twice moved unrelated work onto main (F8.11). HQ Work Items get a separate
# review copy under .hq-reviews/ instead. Refuses if the copy has unsaved edits (files
# git ignores don't count). Prints key=value lines:
#   pr, pr_url, branch, default (branch to return to), path, launch (.claude/launch.json or -)
# Exit: 1 usage/gh error, 2 no open PR for the Issue, 3 unsaved edits,
#       4 your own copy has commits the PR branch doesn't (nothing was touched).
set -euo pipefail

REPO_NAME="${1:-}"; NUM="${2:-}"
if [ -z "$REPO_NAME" ] || [ -z "$NUM" ]; then
  echo "Usage: bash scripts/review-checkout.sh <repo> <issue-number>" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW_ROOT="${HQ_REVIEW_ROOT:-$(cd "$HERE/.." && pwd)/.hq-reviews}"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)"
REPO="$OWNER/$REPO_NAME"

# The open PR that closes this Issue (the builder writes "Closes #<n>")
PR=""
for N in $(gh issue view "$NUM" --repo "$REPO" --json closedByPullRequestsReferences \
             --jq '.closedByPullRequestsReferences[].number'); do
  [ "$(gh pr view "$N" --repo "$REPO" --json state --jq .state)" = OPEN ] && PR="$N"
done
if [ -z "$PR" ]; then
  echo "No open PR closes $REPO#$NUM." >&2
  exit 2
fi
read -r BRANCH PR_URL < <(gh pr view "$PR" --repo "$REPO" --json headRefName,url --jq '"\(.headRefName) \(.url)"')
DEFAULT="$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)"

# Local copy: the first one found that isn't HQ's own folder (you work there), else a
# review copy of its own.
DIR=""
while IFS=$'	' read -r _ D; do
  [ "$D" = "$HERE" ] && continue
  DIR="$D"; break
done < <(bash "$HERE/scripts/find-clones.sh" "$REPO_NAME")

if [ -z "$DIR" ]; then
  DIR="$REVIEW_ROOT/$REPO_NAME"
  if [ -d "$DIR/.git" ]; then
    git -C "$DIR" fetch --quiet origin
  else
    mkdir -p "$(dirname "$DIR")"
    gh repo clone "$REPO" "$DIR" -- --quiet
  fi
fi

if [ -n "$(git -C "$DIR" status --porcelain)" ]; then
  echo "Unsaved edits in $DIR:" >&2
  git -C "$DIR" status --short >&2
  exit 3
fi

# A branch that was rebased and force-pushed has a history the local copy can't fast
# forward to, and merging the two is never what a reviewer wants. A review copy holds
# nothing of yours, so it's reset to the PR head; your own clone is never reset — it
# stops instead, so nothing you have locally is thrown away.
git -C "$DIR" fetch --quiet origin "$BRANCH"

case "$DIR" in
  "$REVIEW_ROOT"/*)
    git -C "$DIR" checkout --quiet -B "$BRANCH" "origin/$BRANCH"
    ;;
  *)
    # Never -B here: that would move your branch and drop commits you haven't pushed.
    if git -C "$DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
      git -C "$DIR" checkout --quiet "$BRANCH"
    else
      git -C "$DIR" checkout --quiet -b "$BRANCH" --track "origin/$BRANCH"
    fi
    if ! git -C "$DIR" merge --ff-only --quiet "origin/$BRANCH" 2>/dev/null; then
      echo "$DIR is on $BRANCH but can't fast-forward to origin/$BRANCH." >&2
      echo "The branch was probably rebased and force-pushed. Your copy still has:" >&2
      git -C "$DIR" log --oneline "origin/$BRANCH..$BRANCH" >&2
      echo "Nothing was changed. Discard those commits, or review from a fresh copy." >&2
      exit 4
    fi
    ;;
esac

LAUNCH="$DIR/.claude/launch.json"
[ -f "$LAUNCH" ] || LAUNCH="-"

printf 'pr=%s\npr_url=%s\nbranch=%s\ndefault=%s\npath=%s\nlaunch=%s\n' \
  "$PR" "$PR_URL" "$BRANCH" "$DEFAULT" "$DIR" "$LAUNCH"
