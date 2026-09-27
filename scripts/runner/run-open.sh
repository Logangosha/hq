#!/usr/bin/env bash
# Opens the run Issue for a manual agent dispatch (workflow_dispatch: agent + ask).
# Usage: AGENT=builder ASK='do the thing' GITHUB_REPOSITORY=owner/repo \
#        bash .hq/scripts/runner/run-open.sh
# Needs GH_TOKEN. Writes num=<issue number> to $GITHUB_OUTPUT (stdout when unset).
set -euo pipefail

: "${AGENT:?}" "${ASK:?}" "${GITHUB_REPOSITORY:?}"

TITLE="Run: $AGENT — $(printf '%s' "$ASK" | head -1 | cut -c1-60)"

BODY_FILE="$(mktemp)"
{
  printf 'Agent: %s\n\n' "$AGENT"
  printf 'Ask:\n\n%s\n\n' "$ASK"
  printf -- '---\nStarted from %s/%s/actions/runs/%s\n' "${GITHUB_SERVER_URL:-https://github.com}" "$GITHUB_REPOSITORY" "${GITHUB_RUN_ID:-}"
} > "$BODY_FILE"

URL="$(gh issue create --repo "$GITHUB_REPOSITORY" --title "$TITLE" --label run --body-file "$BODY_FILE")"
rm -f "$BODY_FILE"

NUM="${URL##*/}"
printf 'num=%s\n' "$NUM" >> "${GITHUB_OUTPUT:-/dev/stdout}"
