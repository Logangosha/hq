#!/usr/bin/env bash
# Put HQ's output-trimming hook where the stage agent's run will pick it up.
# Called by install-agents.sh, so it happens before the agent starts.
# Usage: bash .hq/scripts/runner/install-hooks.sh   (run from the domain checkout,
#        after HQ has been cloned into .hq)
#
# The repo's own file of either name wins and is left exactly as it is (hq#79 R17,
# same rule as install-agents.sh -n).
set -euo pipefail

HQ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mkdir -p .claude/hooks
if [ ! -e .claude/hooks/trim-output.sh ]; then
  cp "$HQ/.claude/hooks/trim-output.sh" .claude/hooks/trim-output.sh
  chmod +x .claude/hooks/trim-output.sh
fi

# settings.local.json, not settings.json: it's gitignored, so the install can never
# turn up in a builder's PR.
if [ ! -e .claude/settings.local.json ]; then
  cp "$HQ/orchestration/agent-hooks.json" .claude/settings.local.json
fi
