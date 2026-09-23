#!/usr/bin/env bash
# Create a Work Item Issue in a domain repo.
#
# Usage:
#   bash scripts/create-work-item.sh owner/repo "Title" "Current state" "Desired state"
#   bash scripts/create-work-item.sh owner/repo "Title" -   # goal body on stdin
#   bash scripts/create-work-item.sh owner/repo "Title" "Current" "Desired" --blocked-by owner/repo#N
#
# The Issue starts at stage:requirements. The label is created if missing.
# With --blocked-by, it starts at waiting:work instead and runs no stage until
# that Work Item's PR merges (see dashboard/server.py's reconcile_blocker).
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/lib/goal-check.sh"

BLOCKED_BY=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --blocked-by)
      BLOCKED_BY="${2:-}"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]}"

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

# --- the blocker, if any -----------------------------------------------------
if [ -n "$BLOCKED_BY" ]; then
  BREPO="${BLOCKED_BY%%#*}"
  BNUM="${BLOCKED_BY##*#}"
  if [ -z "$BREPO" ] || [ -z "$BNUM" ] || [ "$BREPO" = "$BLOCKED_BY" ]; then
    echo "BAD BLOCKER: '$BLOCKED_BY' isn't owner/repo#number. Nothing created." >&2
    exit 4
  fi
  if ! gh issue view "$BNUM" --repo "$BREPO" >/dev/null 2>&1; then
    echo "NO BLOCKER: $BLOCKED_BY doesn't exist (or you can't see it). Nothing created." >&2
    exit 4
  fi
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
ensure_label() {  # name, color, description
  gh label list --repo "$REPO" --search "$1" --json name \
    --jq '.[].name' 2>/dev/null | grep -qx "$1" \
    || gh label create "$1" --repo "$REPO" --color "$2" --description "$3" >/dev/null
}

if [ -n "$BLOCKED_BY" ]; then
  STAGE="waiting:work"
  ensure_label "$STAGE" "F9D0C4" "Another Work Item must finish first"
else
  STAGE="stage:requirements"
  ensure_label "$STAGE" "1D76DB" "Deciding what must be true when done"
fi

# --- create -----------------------------------------------------------------
URL="$(gh issue create \
  --repo "$REPO" \
  --title "Work Item: $TITLE" \
  --body "$BODY" \
  --label "$STAGE")"

if [ -n "$BLOCKED_BY" ]; then
  NUM="${URL##*/}"
  gh issue comment "$NUM" --repo "$REPO" \
    --body "Blocked by \`$BLOCKED_BY\`. Runs no stage until that merges." >/dev/null
fi

echo "$URL"
