#!/usr/bin/env bash
# Put HQ's agents where the run can use them, without overwriting the repo's own.
# Usage: bash .hq/scripts/runner/install-agents.sh   (run from the domain checkout,
#        after HQ has been cloned into .hq)
#
# -n: this repo's own agent of the same name wins (F7.5).
# Also installs HQ's hooks, under the same rule (install-hooks.sh).
set -euo pipefail

mkdir -p .claude/agents
cp -n .hq/.claude/agents/*.md .claude/agents/ || true
bash "$(dirname "${BASH_SOURCE[0]}")/install-hooks.sh"
