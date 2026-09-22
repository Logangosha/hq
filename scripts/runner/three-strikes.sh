#!/usr/bin/env bash
# Three strikes (F7.9). The agents are told to stop by themselves; this is the backstop
# in case one doesn't. A stage comment is headed "## 1. Requirements — requirements",
# so counting the agent's name in the headings counts its runs. Only runs since the
# user's last review decision count: changing your mind twice is normal, and the agents
# shouldn't read it as a loop they're stuck in.
#
# Usage: NUM=29 NAME=verification bash .hq/scripts/runner/three-strikes.sh
# Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
# Exit 1 once the stage has run 3 times, having parked the Work Item.
set -euo pipefail

: "${NUM:?}" "${NAME:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_REPOSITORY_OWNER:?}"

# Requirements is the first stage an Issue reaches, so it's the one place an
# incomplete goal (R1-R3) needs catching before an agent runs at all.
if [ "$NAME" = "requirements" ]; then
  HERE="$(cd "$(dirname "$0")" && pwd)"
  bash "$HERE/check-goal.sh"
fi

RUNS=$(gh issue view "$NUM" --repo "$GITHUB_REPOSITORY" --json comments \
         --jq "[.comments[].body] as \$b
               | (\$b | map(startswith(\"## 6. Review — user\")) | rindex(true)) as \$i
               | (if \$i == null then \$b else \$b[\$i + 1:] end)
               | [.[] | select(startswith(\"## \") and contains(\"— $NAME\"))] | length")
echo "$NAME has run $RUNS time(s) on #$NUM"

if [ "$RUNS" -ge 3 ]; then
  # GITHUB_TOKEN label changes don't trigger workflows, so assign here too.
  gh issue edit "$NUM" --repo "$GITHUB_REPOSITORY" --add-label waiting:user \
    --add-assignee "$GITHUB_REPOSITORY_OWNER"
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
    "🛑 Stopped: **$NAME** has run 3 times on this Work Item. Something upstream is unresolved — a person needs to look. Remove \`waiting:user\` to let it continue."
  exit 1
fi
