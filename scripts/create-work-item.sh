#!/usr/bin/env bash
# Create a Work Item Issue in a domain repo.
#
# Usage:
#   bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
#   bash scripts/create-work-item.sh owner/repo "Title" -   # goal body on stdin
#
# The Issue starts at stage:requirements. The label is created if missing.
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

# --- can we work there? -----------------------------------------------------
# A domain is a repo with the Work Item workflow (see registry/domains.md).
# HQ itself is the one exception: work on the system is tracked there.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
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
