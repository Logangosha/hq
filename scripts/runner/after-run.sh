#!/usr/bin/env bash
# Runs after every stage agent, whether it finished or failed. The place for anything
# that looks back at the run (cost, turns, model). It must never fail the job — the
# workflow step is continue-on-error, and this script should still exit 0.
# Usage: NUM=29 NAME=builder LABEL=stage:build OUTCOME=success \
#        EXECUTION_FILE=/path/to/execution.json bash .hq/scripts/runner/after-run.sh
# EXECUTION_FILE is claude-code-action's run log; it may be empty if the run crashed.
set -euo pipefail

: "${NUM:?}" "${NAME:?}" "${LABEL:?}" "${OUTCOME:?}"

echo "after-run: $NAME for #$NUM ($LABEL) ended $OUTCOME; execution file: ${EXECUTION_FILE:-none}"
