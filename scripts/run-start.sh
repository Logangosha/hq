#!/usr/bin/env bash
# Start a manual agent run (the /run skill's stage 5). Ask text comes on stdin.
# Usage: printf '%s' "$ASK" | bash scripts/run-start.sh <owner/repo> <agent>
#
# Prints (on success): run=<Actions run URL>, issue=<run Issue URL>.
# On timeout waiting for the run Issue: run=<Actions run URL> only.
#
# Exit codes: 0 ok. 1 bad usage. 5 dispatched, but no run Issue appeared in time.
set -euo pipefail

REPO="${1:-}"; AGENT="${2:-}"
if [ -z "$REPO" ] || [ -z "$AGENT" ]; then
  echo "Usage: printf '%s' \"\$ASK\" | bash scripts/run-start.sh <owner/repo> <agent>" >&2
  exit 1
fi

ASK="$(cat; printf x)"; ASK="${ASK%x}"

BEFORE="$(gh run list -R "$REPO" -w work-item.yml -e workflow_dispatch --json databaseId --jq '.[].databaseId' | sort -u)"

RUN_URL="$(jq -nc --arg agent "$AGENT" --arg ask "$ASK" '{agent:$agent,ask:$ask}' \
  | gh workflow run work-item.yml -R "$REPO" --json 2>/dev/null || true)"
RUN_URL="$(printf '%s' "$RUN_URL" | grep -oE 'https://[^ ]+/actions/runs/[0-9]+' | head -1 || true)"

if [ -z "$RUN_URL" ]; then
  for _ in $(seq 1 12); do
    sleep 5
    AFTER="$(gh run list -R "$REPO" -w work-item.yml -e workflow_dispatch --json databaseId --jq '.[].databaseId' | sort -u)"
    NEW_ID="$(comm -13 <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") | head -1)"
    if [ -n "$NEW_ID" ]; then
      RUN_URL="$(gh run view "$NEW_ID" -R "$REPO" --json url --jq .url)"
      break
    fi
  done
fi

if [ -z "$RUN_URL" ]; then
  echo "Dispatched, but no new run was found on $REPO." >&2
  exit 1
fi

RUN_ID="${RUN_URL##*/}"
if ! [[ "$RUN_ID" =~ ^[0-9]+$ ]]; then
  echo "Bad run id from $RUN_URL." >&2
  exit 1
fi
echo "run=$RUN_URL"

for _ in $(seq 1 18); do
  ISSUE_URL="$(gh issue list -R "$REPO" -l run --state all --limit 30 --json url,body \
    --jq ".[] | select(.body | test(\"/actions/runs/${RUN_ID}([^0-9]|\$)\")) | .url" | head -1)"
  [ -n "$ISSUE_URL" ] && { echo "issue=$ISSUE_URL"; exit 0; }
  sleep 10
done

exit 5
