#!/usr/bin/env bash
# Find this computer's clones of the HQ owner's repos.
# Prints "repo<TAB>path", repo in lowercase, one per clone. A repo can have several.
# Usage: bash scripts/find-clones.sh [repo]   (repo: only that one, any case)
#
# Looks up to 3 folders below the folder two levels above HQ (e.g. .../GitHub when HQ is
# .../GitHub/<owner>/hq). Set HQ_LOCAL_ROOT to look elsewhere. Skips the review copies
# under .hq-reviews/ — they're the dashboard's, not yours (F8.11).
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)" || exit 1
ROOT="${HQ_LOCAL_ROOT:-$(cd "$HERE/../.." && pwd)}"
ONLY="$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')"
REVIEWS="${HQ_REVIEW_ROOT:-$(cd "$HERE/.." && pwd)/.hq-reviews}"

find "$ROOT" -maxdepth 4 -path "$REVIEWS" -prune -o -type d -name .git -prune -print 2>/dev/null |
while read -r G; do
  D="$(dirname "$G")"
  URL="$(git -C "$D" remote get-url origin 2>/dev/null)" || continue
  NAME="$(printf '%s' "$URL" | sed -nE "s#.*[:/]$OWNER/([^/]+)\$#\1#Ip" | sed 's/\.git$//' | tr 'A-Z' 'a-z')"
  [ -n "$NAME" ] || continue
  [ -z "$ONLY" ] || [ "$NAME" = "$ONLY" ] || continue
  printf '%s\t%s\n' "$NAME" "$D"
done
exit 0
