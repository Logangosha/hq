#!/usr/bin/env bash
# List this HQ's domains: repos under the same owner as HQ that have the Work Item
# workflow installed. Prints "repo<TAB>description", one per line.
# Usage: bash scripts/list-domains.sh
#
# Nothing is stored in HQ, so a public copy of HQ never shows anyone's repos.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)" || exit 1

check() {  # "name<TAB>description" -> printed if the repo has the workflow
  NAME="${1%%$'\t'*}"
  gh api "repos/$OWNER/$NAME/contents/.github/workflows/work-item.yml" --silent 2>/dev/null \
    && printf '%s\n' "$1"
}
export -f check
export OWNER

gh repo list "$OWNER" --limit 1000 --no-archived --json name,description \
  --jq '.[] | "\(.name)\t\(.description // "")"' |
  tr '\n' '\0' | xargs -0 -P 8 -I{} bash -c 'check "$1"' _ {} | sort
exit 0
