#!/usr/bin/env bash
# Which agent runs this stage, and how many turns it gets.
# Usage: LABEL=stage:build bash .hq/scripts/runner/which-agent.sh
# Writes name= and max_turns= to $GITHUB_OUTPUT (stdout when that isn't set).
# Exit 1 if no agent file exists for the stage.
set -euo pipefail

: "${LABEL:?LABEL is required, e.g. stage:build}"

case "${LABEL#stage:}" in
  plan)  NAME=planner ;;
  build) NAME=builder ;;
  *)     NAME="${LABEL#stage:}" ;;
esac
test -f ".claude/agents/$NAME.md" || { echo "No agent for $LABEL"; exit 1; }

NAME="$NAME" bash "$(dirname "$0")/tool-permissions.sh"

# QA re-runs every check, so it needs more room than the others.
case "$NAME" in
  qa) MAX_TURNS=120 ;;
  *)  MAX_TURNS=80 ;;
esac

printf 'name=%s\nmax_turns=%s\n' "$NAME" "$MAX_TURNS" >> "${GITHUB_OUTPUT:-/dev/stdout}"
