#!/usr/bin/env bash
# The agent step didn't complete (crash, timeout, hitting --max-turns). Nothing else
# records that — without this the Issue would just sit silently.
# Usage: NUM=29 NAME=builder LABEL=stage:build bash .hq/scripts/runner/report-failure.sh
# Needs GH_TOKEN and GITHUB_REPOSITORY.
set -euo pipefail

: "${NUM:?}" "${NAME:?}" "${LABEL:?}" "${GITHUB_REPOSITORY:?}"

gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
  "🛑 The **$NAME** agent step failed to complete for \`$LABEL\` (crash, timeout, or hit its turn limit). The Work Item is unchanged — a person needs to look."
