#!/usr/bin/env bash
# A parent Issue for a big request's ordered parts (orchestration/lifecycle.md,
# features.md F9). A parent is never a Work Item: no `stage:` label, so no agent
# stage ever runs on it. Its `## Parts` list is always regenerated from GitHub's
# sub-issues, so the two can never drift.
#
# Usage:
#   bash scripts/parent.sh create <owner/repo> "Title" "Outcome"
#   bash scripts/parent.sh add <owner/repo#n> <owner/repo#m>
#   bash scripts/parent.sh move <owner/repo#n> <owner/repo#m> --after|--before <owner/repo#k>
#   bash scripts/parent.sh remove <owner/repo#n> <owner/repo#m>
#   bash scripts/parent.sh sync <owner/repo#n>
#   bash scripts/parent.sh close-if-done <owner/repo#n>
#
# Refs are always owner/repo#number. `create` prints the new parent's URL and
# exits 2 if the repo doesn't exist. `add`, `move` and `remove` re-sync the
# parent's body afterwards, so callers never call `sync` themselves.
set -euo pipefail

CMD="${1:-}"; shift || true

ref_repo() { echo "${1%%#*}"; }
ref_num()  { echo "${1##*#}"; }

sub_issue_id() {  # ref -> REST id (the sub-issues API keys on this, not the number)
  gh api "repos/$(ref_repo "$1")/issues/$(ref_num "$1")" --jq .id
}

sync() {
  local parent="$1" repo num list body head new_body
  repo="$(ref_repo "$parent")"; num="$(ref_num "$parent")"
  list="$(gh api "repos/$repo/issues/$num/sub_issues?per_page=100" \
    --jq '[.[] | (.repository_url | sub("^.*/repos/"; "")) + "#" + (.number|tostring)]
          | to_entries | map("\(.key + 1). \(.value)") | join("\n")')"
  [ -z "$list" ] && list="_None yet._"
  body="$(gh issue view "$num" --repo "$repo" --json body --jq .body)"
  head="${body%%## Parts*}"
  new_body="${head}## Parts
$list"
  printf '%s\n' "$new_body" | gh issue edit "$num" --repo "$repo" --body-file - >/dev/null
}

create() {
  local repo="$1" title="$2" outcome="$3" body
  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "NO REPO: $repo doesn't exist (or you can't see it). Nothing created." >&2
    exit 2
  fi
  body="## Outcome
$outcome

## Parts
_None yet._"
  gh issue create --repo "$repo" --title "Parent: $title" --body "$body"
}

add() {
  local parent="$1" part="$2" id
  id="$(sub_issue_id "$part")"
  gh api -X POST "repos/$(ref_repo "$parent")/issues/$(ref_num "$parent")/sub_issues" \
    -F sub_issue_id="$id" >/dev/null
  sync "$parent"
}

move() {
  local parent="$1" part="$2" mode="$3" other="$4" id oid field
  id="$(sub_issue_id "$part")"
  oid="$(sub_issue_id "$other")"
  case "$mode" in
    --after) field=after_id ;;
    --before) field=before_id ;;
    *) echo "BAD MOVE: '$mode' — use --after or --before." >&2; exit 4 ;;
  esac
  gh api -X PATCH "repos/$(ref_repo "$parent")/issues/$(ref_num "$parent")/sub_issues/priority" \
    -F sub_issue_id="$id" -F "$field=$oid" >/dev/null
  sync "$parent"
}

remove() {
  local parent="$1" part="$2" id
  id="$(sub_issue_id "$part")"
  gh api -X DELETE "repos/$(ref_repo "$parent")/issues/$(ref_num "$parent")/sub_issue" \
    -F sub_issue_id="$id" >/dev/null
  sync "$parent"
}

close_if_done() {
  local parent="$1" repo num open
  repo="$(ref_repo "$parent")"; num="$(ref_num "$parent")"
  open="$(gh api "repos/$repo/issues/$num/sub_issues?per_page=100" \
    --jq '[.[] | select(.state == "open")] | length')"
  if [ "$open" -eq 0 ]; then
    gh issue comment "$num" --repo "$repo" \
      --body "All parts are closed, so this parent is closed." >/dev/null
    gh issue close "$num" --repo "$repo" --reason completed >/dev/null
  else
    echo "open=$open"
  fi
}

case "$CMD" in
  create)         create "$@" ;;
  add)             add "$@" ;;
  move)            move "$@" ;;
  remove)          remove "$@" ;;
  sync)            sync "$1" ;;
  close-if-done)   close_if_done "$1" ;;
  *)
    echo "Usage: bash scripts/parent.sh create|add|move|remove|sync|close-if-done ..." >&2
    exit 1
    ;;
esac
