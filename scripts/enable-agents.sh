#!/usr/bin/env bash
# Let a domain repo run the Work Item agents.
# Usage: bash scripts/enable-agents.sh owner/repo
#
# Installs the stage-label workflow and the labels. The repo also needs the
# CLAUDE_CODE_OAUTH_TOKEN secret — this script checks and tells you if it's missing.
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: bash scripts/enable-agents.sh owner/repo" >&2
  exit 1
fi

HQ_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PATH_IN_REPO=".github/workflows/work-item.yml"

CONTENT="$(sed "s|__HQ_REPO__|${HQ_REPO}|g" "$HERE/orchestration/work-item.yml" | base64 -w0)"

SHA="$(gh api "repos/$REPO/contents/$PATH_IN_REPO" --jq .sha 2>/dev/null || true)"

gh api "repos/$REPO/contents/$PATH_IN_REPO" -X PUT \
  -f message="Run Work Item agents from $HQ_REPO" \
  -f content="$CONTENT" \
  ${SHA:+-f sha="$SHA"} >/dev/null

bash "$HERE/scripts/create-labels.sh" "$REPO"

if gh secret list --repo "$REPO" | grep -q CLAUDE_CODE_OAUTH_TOKEN; then
  echo "Agents enabled in $REPO."
else
  echo "Workflow installed in $REPO, but the secret is missing. Run:"
  echo "  gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $REPO"
fi
