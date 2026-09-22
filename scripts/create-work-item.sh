#!/usr/bin/env bash
# Create a Work Item Issue in a domain repo.
#
# Usage:
#   bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
#   bash scripts/create-work-item.sh owner/repo "Title" -   # goal body on stdin
#
# The Issue starts at stage:requirements. The label is created if missing.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/lib/goal-check.sh"

REPO="${1:-}"
TITLE="${2:-}"

if [ -z "$REPO" ] || [ -z "$TITLE" ]; then
  cat >&2 <<'USAGE'
Usage: bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
       bash scripts/create-work-item.sh owner/repo "Title" -    (goal body on stdin)
USAGE
  exit 1
fi

# --- can we work there? -----------------------------------------------------
# A domain is a repo with the Work Item workflow (see registry/domains.md).
# HQ itself is the one exception: work on the system is tracked there.
HQ_REPO="$(cd "$HERE" && gh repo view --json nameWithOwner --jq .nameWithOwner)"

if ! gh repo view "$REPO" >/dev/null 2>&1; then
  echo "NO REPO: $REPO doesn't exist (or you can't see it). Nothing created." >&2
  echo "To start working there: /add-domain ${REPO##*/}" >&2
  exit 2
fi
if [ "$REPO" != "$HQ_REPO" ] && \
   ! gh api "repos/$REPO/contents/.github/workflows/work-item.yml" --silent 2>/dev/null; then
  echo "NOT A DOMAIN: $REPO exists but has no Work Item workflow, so no agent would run." >&2
  echo "Nothing created. To set it up: /add-domain ${REPO##*/}" >&2
  exit 3
fi

# --- the goal ---------------------------------------------------------------
if [ "${3:-}" = "-" ]; then
  GOAL="$(cat)"
  MISSING="$(printf '%s\n' "$GOAL" | goal_missing_parts)"
  if [ -n "$MISSING" ]; then
    echo "Goal is missing: $(printf '%s' "$MISSING" | goal_join_missing). Nothing created." >&2
    exit 1
  fi
else
  CURRENT="$(_goal_trim "${3:-}")"
  DESIRED="$(_goal_trim "${4:-}")"
  MISSING=""
  [ -z "$CURRENT" ] && MISSING="${MISSING}current state
"
  [ -z "$DESIRED" ] && MISSING="${MISSING}desired state
"
  if [ -n "$MISSING" ]; then
    echo "Goal is missing: $(printf '%s' "$MISSING" | goal_join_missing). Nothing created." >&2
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
STAGE="stage:requirements"

ensure_label() {  # name, color, description
  gh label list --repo "$REPO" --search "$1" --json name \
    --jq '.[].name' 2>/dev/null | grep -qx "$1" \
    || gh label create "$1" --repo "$REPO" --color "$2" --description "$3" >/dev/null
}

ensure_label "$STAGE" "1D76DB" "Deciding what must be true when done"

# --- create -----------------------------------------------------------------
URL="$(gh issue create \
  --repo "$REPO" \
  --title "Work Item: $TITLE" \
  --body "$BODY" \
  --label "$STAGE")"

echo "$URL"
