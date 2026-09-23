#!/usr/bin/env bash
# The command-line flags the stage agent's Claude run gets. Built here, not in the
# workflow, so agents can change them (model, effort, limits) — a file under
# .github/workflows/ is one they are never allowed to push.
# Usage: NAME=builder MAX_TURNS=80 bash .hq/scripts/runner/claude-args.sh
# Writes args=<flags> to $GITHUB_OUTPUT (stdout when that isn't set).
set -euo pipefail

: "${NAME:?}" "${MAX_TURNS:?}"

# bypassPermissions: no one is here to approve prompts, and without it writes to
# .claude/ (skills, agents) are always refused. The runner is thrown away after the
# run; everything still reaches main only through a reviewed PR.
ARGS="--permission-mode bypassPermissions --allowedTools \"Bash,Read,Write,Edit,Glob,Grep\" --max-turns $MAX_TURNS"

printf 'args=%s\n' "$ARGS" >> "${GITHUB_OUTPUT:-/dev/stdout}"
