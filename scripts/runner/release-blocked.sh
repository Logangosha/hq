#!/usr/bin/env bash
# Release waiting:work Work Items whose blockers are all settled (F7 gap: the runner
# didn't do this, only the dashboard's reconcile_blockers on a refresh). Same rules as
# dashboard/server.py: parse_blockers/blocker_state/reconcile_blockers.
# Usage: bash .hq/scripts/runner/release-blocked.sh              # sweep every domain
#        bash .hq/scripts/runner/release-blocked.sh owner/repo#n # one item (QA)
# Needs GH_TOKEN with cross-repo Issues read/write (HQ_RELEASE_TOKEN).
set -uo pipefail

if [ -z "${GH_TOKEN:-}" ]; then
  echo "HQ_RELEASE_TOKEN secret missing — run check-setup" >&2
  exit 1
fi

BLOCKER_RE='Blocked by ((`[^`]+`(, )?)+)'
ANSWER_RE='^## Answer — user'
RELEASED_RE='^Blockers? .*(merged|done)\. Starting '

# parse_blockers <comments-json> -> one owner/repo#n per line, from the first
# comment matching BLOCKER_RE (same as dashboard/server.py's BLOCKER_REF_RE).
parse_blockers() {
  jq -r --arg re "$BLOCKER_RE" '
    [.[] | select(.body | test($re))][0].body
    // empty
    | scan($re)[0]
    | scan("`([^`]+)`")[0]
  ' <<<"$1" 2>/dev/null
}

# blocker_state owner/repo#n -> merged | open | "closed without merging"
blocker_state() {
  local ref="$1" bfull bnum info state reason
  bfull="${ref%#*}"; bnum="${ref##*#}"
  info="$(gh issue view "$bnum" --repo "$bfull" --json state,stateReason 2>/dev/null)" || { echo open; return; }
  state="$(jq -r .state <<<"$info")"
  [ "$state" != CLOSED ] && { echo open; return; }
  reason="$(jq -r .stateReason <<<"$info")"
  [ "$reason" = COMPLETED ] && echo merged || echo "closed without merging"
}

blocker_closed_at() {
  gh issue view "${1##*#}" --repo "${1%#*}" --json closedAt --jq .closedAt 2>/dev/null
}

# settled owner/repo#n <item-comments-json> -> 0 if this blocker no longer holds the item
settled() {
  local ref="$1" comments="$2" st closed_at
  st="$(blocker_state "$ref")"
  [ "$st" = merged ] && return 0
  [ "$st" = open ] && return 1
  closed_at="$(blocker_closed_at "$ref")"
  [ -z "$closed_at" ] && return 1
  jq -e --arg re "$ANSWER_RE" --arg closed "$closed_at" '
    any(.[]; (.body | test($re)) and .createdAt > $closed)
  ' <<<"$comments" >/dev/null
}

release_one() {
  local full="$1" num="$2"
  local it comments labels small refs ref next_label next_name

  it="$(gh issue view "$num" --repo "$full" --json labels,comments 2>/dev/null)" || return
  labels="$(jq -r '.labels[].name' <<<"$it")"
  grep -qx 'waiting:work' <<<"$labels" || return
  grep -q '^stage:' <<<"$labels" && return
  grep -qx 'waiting:user' <<<"$labels" && return

  comments="$(jq '.comments' <<<"$it")"
  mapfile -t refs < <(parse_blockers "$comments")
  [ "${#refs[@]}" -eq 0 ] && return

  for ref in "${refs[@]}"; do
    settled "$ref" "$comments" || return
  done

  # Fresh re-check right before releasing (R5): another release may have run since
  # the read above (this runner sweep, another domain's, or the dashboard's).
  it="$(gh issue view "$num" --repo "$full" --json labels,comments 2>/dev/null)" || return
  labels="$(jq -r '.labels[].name' <<<"$it")"
  grep -qx 'waiting:work' <<<"$labels" || return
  grep -q '^stage:' <<<"$labels" && return
  grep -qx 'waiting:user' <<<"$labels" && return
  comments="$(jq '.comments' <<<"$it")"
  jq -e --arg re "$RELEASED_RE" 'any(.[]; .body | test($re))' <<<"$comments" >/dev/null && return

  small="normal"
  grep -qx 'size:small' <<<"$labels" && small="small"
  if [ "$small" = small ]; then next_label="stage:scope"; next_name="Scope"; else next_label="stage:requirements"; next_name="Requirements"; fi

  local text
  if [ "${#refs[@]}" -eq 1 ]; then
    text="Blocker \`${refs[0]}\` merged. Starting $next_name."
  else
    local joined=""
    for ref in "${refs[@]}"; do joined+="${joined:+, }\`$ref\`"; done
    text="Blockers $joined done. Starting $next_name."
  fi

  gh issue comment "$num" --repo "$full" --body "$text"
  # Two calls, remove then add: the labeled event that starts the next agent must
  # not still show waiting:work, or the runner's waiting: guard skips it.
  gh issue edit "$num" --repo "$full" --remove-label waiting:work
  gh issue edit "$num" --repo "$full" --add-label "$next_label"
}

if [ -n "${1:-}" ]; then
  ref="$1"
  release_one "${ref%#*}" "${ref##*#}"
  exit 0
fi

HERE="$(cd "$(dirname "$0")/../.." && pwd)"
OWNER="${GITHUB_REPOSITORY_OWNER:-$(gh repo view --json owner --jq .owner.login)}"
while IFS=$'\t' read -r NAME _; do
  [ -z "$NAME" ] && continue
  FULL="$OWNER/$NAME"
  for NUM in $(gh issue list --repo "$FULL" --label waiting:work --state open --json number --jq '.[].number'); do
    release_one "$FULL" "$NUM"
  done
done < <(bash "$HERE/scripts/list-domains.sh")
