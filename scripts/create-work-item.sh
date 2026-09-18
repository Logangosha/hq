#!/usr/bin/env bash
# Create a Work Item Issue in a domain repo.
#
# Usage:
#   bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
#   bash scripts/create-work-item.sh owner/repo "Title" -   # goal body on stdin
#
# The Issue starts at stage:requirements. Missing labels are created.
set -euo pipefail

REPO="${1:-}"
TITLE="${2:-}"

if [ -z "$REPO" ] || [ -z "$TITLE" ]; then
  cat >&2 <<'USAGE'
Usage: bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
       bash scripts/create-work-item.sh owner/repo "Title" -    (goal body on stdin)
USAGE
  exit 1
fi

# --- the goal ---------------------------------------------------------------
if [ "${3:-}" = "-" ]; then
  GOAL="$(cat)"
else
  CURRENT="${3:-}"
  DESIRED="${4:-}"
  if [ -z "$CURRENT" ] || [ -z "$DESIRED" ]; then
    echo "Give both a current state and a desired state, or pass - and pipe the goal in." >&2
    exit 1
  fi
  GOAL="**Current state:** $CURRENT

**Desired state:** $DESIRED"
fi

# The body is the goal only. Every stage after this is a comment. See
# orchestration/lifecycle.md, "How the Issue is written".
BODY="## Goal
$GOAL"

# --- labels -----------------------------------------------------------------
# domain: is the repo name, so a Work Item can be found without opening it.
DOMAIN="domain:${REPO##*/}"
STAGE="stage:requirements"

ensure_label() {  # name, color, description
  gh label list --repo "$REPO" --search "$1" --json name \
    --jq '.[].name' 2>/dev/null | grep -qx "$1" \
    || gh label create "$1" --repo "$REPO" --color "$2" --description "$3" >/dev/null
}

ensure_label "$STAGE" "1D76DB" "Deciding what must be true when done"
ensure_label "$DOMAIN" "BFD4F2" "Work belonging to ${REPO##*/}"

# --- create -----------------------------------------------------------------
URL="$(gh issue create \
  --repo "$REPO" \
  --title "Work Item: $TITLE" \
  --body "$BODY" \
  --label "$STAGE" \
  --label "$DOMAIN")"

echo "$URL"
