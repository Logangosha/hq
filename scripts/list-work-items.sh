#!/usr/bin/env bash
# List every domain's open Work Items, grouped by domain.
# Prints "DOMAIN<TAB><owner>/<repo>", then one
# "<repo><TAB><number><TAB><title><TAB><stage><TAB><url><TAB><waiting labels, comma-separated>"
# line per open Work Item (an open Issue with a stage: label) in that domain.
# The DOMAIN line prints even when the domain has no open Work Items.
# Usage: bash scripts/list-work-items.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)" || exit 1

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

bash scripts/list-domains.sh | while IFS=$'\t' read -r REPO _DESC; do
  printf 'DOMAIN\t%s/%s\n' "$OWNER" "$REPO"
  gh issue list --repo "$OWNER/$REPO" --state open --limit 1000 \
    --json number,title,url,labels \
    --jq '.[] | [.number, .title, (.labels[].name | select(startswith("stage:"))), .url,
             ([.labels[].name | select(startswith("waiting:"))] | join(","))] | @tsv' |
  while IFS=$'\t' read -r NUMBER TITLE LABEL URL WAITING; do
    [ -z "$LABEL" ] && continue
    STAGE="$(stage_name "$LABEL")"
    [ -z "$STAGE" ] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$REPO" "$NUMBER" "$TITLE" "$STAGE" "$URL" "$WAITING"
  done
done
exit 0
