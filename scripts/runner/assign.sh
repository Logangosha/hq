#!/usr/bin/env bash
# Assignment is how the user is told it's their turn (F8.1): assigned means "needs you",
# so the phone app pings. The agents unassign when they take the work back.
# Usage: NUM=29 bash .hq/scripts/runner/assign.sh add|remove
# Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
set -euo pipefail

: "${NUM:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_REPOSITORY_OWNER:?}"
case "${1:-}" in
  add|remove) ACTION="$1" ;;
  *) echo "Usage: NUM=<n> bash $0 add|remove" >&2; exit 1 ;;
esac

gh issue edit "$NUM" --repo "$GITHUB_REPOSITORY" \
  "--$ACTION-assignee" "$GITHUB_REPOSITORY_OWNER"
