#!/usr/bin/env bash
# List this HQ's domains: repos under the same owner as HQ tagged with the `hq-domain`
# GitHub topic. Prints "repo<TAB>description", one per line.
# Usage: bash scripts/list-domains.sh
#
# Nothing is stored in HQ, so a public copy of HQ never shows anyone's repos.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)" || exit 1

gh repo list "$OWNER" --topic hq-domain --no-archived --limit 1000 --json name,description \
  --jq '.[] | "\(.name)\t\(.description // "")"' | sort
exit 0
