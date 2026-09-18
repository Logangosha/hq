#!/usr/bin/env bash
# List every repo of HQ's owner: is it a domain, is it cloned on this computer, is it private.
# Prints "repo<TAB>domain<TAB>local<TAB>private<TAB>description", one per line.
# domain = yes/no. local = path(s) of clones found on this computer, or "-".
# Usage: bash scripts/list-repos.sh
#
# Clones are found by scripts/find-clones.sh.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)" || exit 1

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Domains, using the same rule as list-domains.sh
bash "$HERE/scripts/list-domains.sh" | cut -f1 | tr 'A-Z' 'a-z' > "$TMP/domains"

bash "$HERE/scripts/find-clones.sh" > "$TMP/local"

gh repo list "$OWNER" --limit 1000 --no-archived --json name,isPrivate,description \
  --jq '.[] | "\(.name)\t\(.isPrivate)\t\(.description // "")"' | sort -f |
while IFS=$'\t' read -r NAME PRIV DESC; do
  KEY="$(printf '%s' "$NAME" | tr 'A-Z' 'a-z')"
  grep -qxF "$KEY" "$TMP/domains" && DOM=yes || DOM=no
  LOC="$(awk -F'\t' -v k="$KEY" '$1==k {print $2}' "$TMP/local" | paste -sd, -)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$NAME" "$DOM" "${LOC:--}" "$PRIV" "$DESC"
done
exit 0
