#!/usr/bin/env bash
# The command-line flags the stage agent's Claude run gets. Built here, not in the
# workflow, so agents can change them (model, effort, limits) — a file under
# .github/workflows/ is one they are never allowed to push.
# Model and effort come from the stage agent's own frontmatter
# (.claude/agents/$NAME.md, installed into the domain checkout by
# install-agents.sh), unless three-strikes.sh flagged this as a rebuild after a QA
# fail, in which case it's overridden to opus/high (hq#78 R5).
# Usage: NAME=builder MAX_TURNS=80 bash .hq/scripts/runner/claude-args.sh
# Writes args=<flags> to $GITHUB_OUTPUT (stdout when that isn't set).
set -euo pipefail

: "${NAME:?}" "${MAX_TURNS:?}"

AGENT_FILE=".claude/agents/$NAME.md"
test -f "$AGENT_FILE" || { echo "No agent file at $AGENT_FILE"; exit 1; }
FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$AGENT_FILE")"
MODEL="$(sed -n 's/^model: *//p' <<<"$FRONTMATTER" | head -1)"
EFFORT="$(sed -n 's/^effort: *//p' <<<"$FRONTMATTER" | head -1)"
: "${MODEL:?no model: in $AGENT_FILE}" "${EFFORT:?no effort: in $AGENT_FILE}"

if [ "$NAME" = builder ] && [ "$(cat "${RUNNER_TEMP:-/tmp}/hq-rebuild-escalate" 2>/dev/null || echo false)" = true ]; then
  MODEL=opus
  EFFORT=high
fi

# bypassPermissions: no one is here to approve prompts, and without it writes to
# .claude/ (skills, agents) are always refused. The runner is thrown away after the
# run; everything still reaches main only through a reviewed PR.
ARGS="--permission-mode bypassPermissions --allowedTools \"Bash,Read,Write,Edit,Glob,Grep\" --max-turns $MAX_TURNS --model $MODEL --effort $EFFORT"

# Settings carry HQ's hooks (install-hooks.sh put them there). Named explicitly so the
# run doesn't depend on the action picking project settings up on its own.
if [ -f .claude/settings.local.json ]; then
  ARGS="$ARGS --settings .claude/settings.local.json"
fi

printf 'args=%s\n' "$ARGS" >> "${GITHUB_OUTPUT:-/dev/stdout}"
