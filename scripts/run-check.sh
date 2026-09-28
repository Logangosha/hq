#!/usr/bin/env bash
# Check a target repo and agent before a manual run (the /run skill's stage 2 & 3).
# Usage: bash scripts/run-check.sh <repo> <agent>
#
# Prints (on success): repo=<owner/repo>, then the agent file's contents, then
# source=repo|hq (repo's own .claude/agents/<agent>.md wins over HQ's, same rule as
# scripts/runner/install-agents.sh).
# If <agent> names a workflow (workflows/<name>.md in the repo, else HQ's) it is a
# workflow, not an agent: prints the file, source=repo|hq, kind=workflow, and one
# required=<input> per `yes` Input.
#
# Exit codes: 0 ok. 1 bad usage. 4 repo has no Work Item workflow with
# workflow_dispatch. 3 the agent isn't in the repo or in HQ.
set -euo pipefail

REPO_NAME="${1:-}"; AGENT="${2:-}"
if [ -z "$REPO_NAME" ] || [ -z "$AGENT" ]; then
  echo "Usage: bash scripts/run-check.sh <repo> <agent>" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$REPO_NAME" == */* ]]; then
  REPO="$REPO_NAME"
else
  OWNER="$(cd "$HERE" && gh repo view --json owner --jq .owner.login)"
  REPO="$OWNER/$REPO_NAME"
fi

if ! [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
  echo "Bad agent name: $AGENT" >&2
  exit 3
fi

echo "repo=$REPO"

# Decide by gh api's exit status: on a 404, --jq prints the raw error JSON to stdout.
if ! B64="$(gh api "repos/$REPO/contents/.github/workflows/work-item.yml" --jq '.content' 2>/dev/null)" \
  || ! base64 -d <<<"$B64" 2>/dev/null | grep -q 'workflow_dispatch'; then
  echo "No Work Item workflow with a manual trigger in $REPO." >&2
  exit 4
fi

# shellcheck source=lib/flow-fetch.sh
. "$HERE/scripts/lib/flow-fetch.sh"
# shellcheck source=runner/flow-lib.sh
. "$HERE/scripts/runner/flow-lib.sh"
FLOW_TMP_FILE="$(mktemp)"
if FLOW_SRC="$(flow_fetch "$REPO" "$AGENT" "$FLOW_TMP_FILE")"; then
  cat "$FLOW_TMP_FILE"
  echo "source=$FLOW_SRC"
  echo "kind=workflow"
  flow_rows "$FLOW_TMP_FILE" Inputs | awk -F'\t' '$2 == "yes" { print "required=" $1 }'
  rm -f "$FLOW_TMP_FILE"
  exit 0
fi
rm -f "$FLOW_TMP_FILE"

if B64="$(gh api "repos/$REPO/contents/.claude/agents/$AGENT.md" --jq '.content' 2>/dev/null)"; then
  printf '%s\n' "$(base64 -d <<<"$B64")"
  echo "source=repo"
  exit 0
fi

if [ -f "$HERE/.claude/agents/$AGENT.md" ]; then
  cat "$HERE/.claude/agents/$AGENT.md"
  echo "source=hq"
  exit 0
fi

echo "No agent named $AGENT in $REPO or in HQ." >&2
exit 3
