#!/usr/bin/env bash
# Create the Work Item labels in a repo.
# Usage: bash scripts/create-labels.sh owner/repo
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: bash scripts/create-labels.sh owner/repo" >&2
  exit 1
fi

# name|color|description
LABELS=(
  "stage:requirements|1D76DB|Deciding what must be true when done"
  "stage:verification|0E8A16|Writing the checks that prove it"
  "stage:plan|5319E7|Deciding how to do it"
  "stage:build|FBCA04|Doing the work"
  "stage:qa|006B75|Running the checks"
  "stage:review|D93F0B|Waiting for the user to look at it"
  "waiting:user|E99695|A question or decision is needed"
  "waiting:work|F9D0C4|Another Work Item must finish first"
  "waiting:stopped|C5DEF5|Paused by the user, not the agents"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
done

echo "Labels ready in $REPO."
echo "Note: workflow:<name> labels are created as they are needed."
