#!/usr/bin/env bash
# List every repo of HQ's owner: is it a domain, is it cloned on this computer, is it private.
# Prints "repo<TAB>domain<TAB>local<TAB>private<TAB>description", one per line.
# domain = yes/no. local = path(s) of clones found on this computer, or "-".
# Usage: bash scripts/list-repos.sh
#
# Clones are looked for up to 3 folders below the folder two levels above HQ
# (e.g. .../GitHub when HQ is .../GitHub/<owner>/hq). Set HQ_LOCAL_ROOT to look elsewhere.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
read -r OWNER SELF < <(cd "$HERE" && gh repo view --json owner,name --jq "(.owner.login) (.name)") || exit 1
ROOT="${HQ_LOCAL_ROOT:-$(cd "$HERE/../.." && pwd)}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Domains, using the same rule as list-domains.sh
bash "$HERE/scripts/list-domains.sh" | cut -f1 | tr 'A-Z' 'a-z' > "$TMP/domains"

# Local clones: "lowercase-repo<TAB>path" for each one whose origin is this owner's
find "$ROOT" -maxdepth 4 -type d -name .git -prune 2>/dev/null | while read -r G; do
  D="$(dirname "$G")"
  URL="$(git -C "$D" remote get-url origin 2>/dev/null)" || continue
  NAME="$(printf '%s' "$URL" | sed -nE "s#.*[:/]$OWNER/([^/]+)\$#\1#Ip" | sed 's/\.git$//')"
  [ -n "$NAME" ] && printf '%s\t%s\n' "$(printf '%s' "$NAME" | tr 'A-Z' 'a-z')" "$D"
done > "$TMP/local"

gh repo list "$OWNER" --limit 1000 --no-archived --json name,isPrivate,description \
  --jq '.[] | "\(.name)\t\(.isPrivate)\t\(.description // "")"' | sort -f |
while IFS=$'\t' read -r NAME PRIV DESC; do
  KEY="$(printf '%s' "$NAME" | tr 'A-Z' 'a-z')"
  grep -qxF "$KEY" "$TMP/domains" && DOM=yes || DOM=no
  LOC="$(awk -F'\t' -v k="$KEY" '$1==k {print $2}' "$TMP/local" | paste -sd, -)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$NAME" "$DOM" "${LOC:--}" "$PRIV" "$DESC"
done
exit 0
