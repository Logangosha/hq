#!/usr/bin/env bash
# List this HQ's domains: repos under the same owner as HQ tagged with the `hq-domain`
# GitHub topic. Prints "repo<TAB>description", one per line.
# Usage: bash scripts/list-domains.sh
#
# Nothing is stored in HQ, so a public copy of HQ never shows anyone's repos.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/lib/gh-refusal.sh"

OWNER="$(cd "$HERE" && gh_or_refusal gh repo view --json owner --jq .owner.login)"
STATUS=$?
[ "$STATUS" -eq 2 ] && { printf '%s\n' "$OWNER"; exit 2; }
[ "$STATUS" -ne 0 ] && exit 1

REPOS="$(gh_or_refusal gh repo list "$OWNER" --topic hq-domain --no-archived --limit 1000 \
  --json name,description --jq '.[] | "\(.name)\t\(.description // "")"')"
STATUS=$?
[ "$STATUS" -eq 2 ] && { printf '%s\n' "$REPOS"; exit 2; }
[ "$STATUS" -ne 0 ] && exit 1

[ -z "$REPOS" ] && exit 0
printf '%s\n' "$REPOS" | sort
exit 0
