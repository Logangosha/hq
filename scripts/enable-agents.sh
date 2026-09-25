#!/usr/bin/env bash
# Let a domain repo run the Work Item agents.
# Usage: bash scripts/enable-agents.sh owner/repo [hq-ref]
#
# Installs the small stub workflow (which calls HQ's runner at hq-ref, default main)
# and the labels. Re-running it is safe. The repo also needs the CLAUDE_CODE_OAUTH_TOKEN
# and HQ_RELEASE_TOKEN secrets — this script checks and tells you if either is missing.
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: bash scripts/enable-agents.sh owner/repo [hq-ref]" >&2
  exit 1
fi

REF="${2:-main}"
HQ_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PATH_IN_REPO=".github/workflows/work-item.yml"

CONTENT="$(sed -e "s|__HQ_REPO__|${HQ_REPO}|g" -e "s|__REF__|${REF}|g" "$HERE/orchestration/work-item.yml" | base64 -w0)"

SHA="$(gh api "repos/$REPO/contents/$PATH_IN_REPO" --jq .sha 2>/dev/null || true)"

gh api "repos/$REPO/contents/$PATH_IN_REPO" -X PUT \
  -f message="Run Work Item agents from $HQ_REPO" \
  -f content="$CONTENT" \
  ${SHA:+-f sha="$SHA"} >/dev/null

bash "$HERE/scripts/create-labels.sh" "$REPO"

MISSING=""
gh secret list --repo "$REPO" | grep -q CLAUDE_CODE_OAUTH_TOKEN || MISSING="$MISSING CLAUDE_CODE_OAUTH_TOKEN"
gh secret list --repo "$REPO" | grep -q HQ_RELEASE_TOKEN || MISSING="$MISSING HQ_RELEASE_TOKEN"

if [ -z "$MISSING" ]; then
  echo "Agents enabled in $REPO."
else
  echo "Workflow installed in $REPO, but secret(s) are missing. Run:"
  for S in $MISSING; do echo "  gh secret set $S --repo $REPO"; done
fi
