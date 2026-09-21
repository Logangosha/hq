#!/usr/bin/env bash
# List every domain's open Work Items, grouped by domain.
# Prints "DOMAIN<TAB><owner>/<repo>", then one
# "<repo><TAB><number><TAB><title><TAB><stage><TAB><url><TAB><waiting labels, comma-separated>"
# line per open Work Item (an open Issue with a stage: label) in that domain.
# The DOMAIN line prints even when the domain has no open Work Items.
# Usage: bash scripts/list-work-items.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/lib/gh-refusal.sh"

OWNER="$(cd "$HERE" && gh_or_refusal gh repo view --json owner --jq .owner.login)"
STATUS=$?
[ "$STATUS" -eq 2 ] && { printf '%s\n' "$OWNER"; exit 2; }
[ "$STATUS" -ne 0 ] && exit 1

stage_name() {
  case "$1" in
    stage:requirements) echo "1 Requirements" ;;
    stage:verification) echo "2 Verification" ;;
    stage:plan) echo "3 Plan" ;;
    stage:build) echo "4 Build" ;;
    stage:qa) echo "5 QA" ;;
    stage:review) echo "6 Human review" ;;
    *) echo "" ;;
  esac
}

DOMAINS="$(bash scripts/list-domains.sh)"
STATUS=$?
[ "$STATUS" -eq 2 ] && { printf '%s\n' "$DOMAINS"; exit 2; }
[ "$STATUS" -ne 0 ] && exit 1

printf '%s\n' "$DOMAINS" | while IFS=$'\t' read -r REPO _DESC; do
  [ -z "$REPO" ] && continue
  printf 'DOMAIN\t%s/%s\n' "$OWNER" "$REPO"
  ISSUES="$(gh_or_refusal gh issue list --repo "$OWNER/$REPO" --state open --limit 1000 \
    --json number,title,url,labels \
    --jq '.[] | [.number, .title, ([.labels[].name | select(startswith("stage:"))][0] // "-"), .url,
             (([.labels[].name | select(startswith("waiting:"))] | join(",")) // "" | if . == "" then "-" else . end)] | @tsv')"
  ISTATUS=$?
  [ "$ISTATUS" -eq 2 ] && { printf '%s\n' "$ISSUES"; exit 2; }
  [ "$ISTATUS" -ne 0 ] && exit 1
  [ -z "$ISSUES" ] && continue
  printf '%s\n' "$ISSUES" |
  while IFS=$'\t' read -r NUMBER TITLE LABEL URL WAITING; do
    # "-" stands in for an empty field: the shell would otherwise swallow it.
    [ "$LABEL" = "-" ] && LABEL=""
    [ "$WAITING" = "-" ] && WAITING=""
    STAGE="$(stage_name "$LABEL")"
    # An agent that stops can leave no stage: label at all. Those still need a person,
    # so they must not vanish from the list.
    [ -z "$STAGE" ] && [ -z "$WAITING" ] && continue
    [ -z "$STAGE" ] && STAGE="0 Stopped"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$REPO" "$NUMBER" "$TITLE" "$STAGE" "$URL" "$WAITING"
  done
done
STATUS=$?
[ "$STATUS" -eq 2 ] && exit 2
[ "$STATUS" -ne 0 ] && exit 1
exit 0
