#!/usr/bin/env bash
# Three strikes (F7.9, hq#188). The agents are told to stop by themselves; this is the
# backstop in case one doesn't. A stage comment is headed "## 1. Requirements —
# requirements", so counting the agent's name in the headings counts its runs. Only the
# heading line counts: a comment's body may quote another stage's heading (hq#78 did, and
# got parked before QA ever ran). Only runs since the latest comment by a person (not a
# bot) count — that includes a `## 6. Review — user` decision, but also any other comment
# from the repo owner (e.g. the dashboard's Answer button, or just "go"): a person having
# looked is what resets the count, not a specific ritual. Bot-ness comes from the REST
# API's `user.type`, since `gh issue view`'s comments don't carry it (`claude[bot]` shows
# up as `claude`).
#
# Usage: NUM=29 NAME=verification bash .hq/scripts/runner/three-strikes.sh
# Needs GH_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
# Exit 1 once the stage has run 3 times, having parked the Work Item.
set -euo pipefail

: "${NUM:?}" "${NAME:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_REPOSITORY_OWNER:?}"

# Requirements and Scope are the first stage an Issue can reach, so they're the
# place an incomplete goal (R1-R3) needs catching before an agent runs at all.
if [ "$NAME" = "requirements" ] || [ "$NAME" = "scope" ]; then
  HERE="$(cd "$(dirname "$0")" && pwd)"
  bash "$HERE/check-goal.sh"
fi

COMMENTS=$(gh api "repos/$GITHUB_REPOSITORY/issues/$NUM/comments" --paginate \
             --jq '.[] | {body, bot: (.user.type == "Bot")}' | jq -s .)

RUNS=$(echo "$COMMENTS" | jq --arg name "$NAME" '
  . as $c
  | ($c | map(.body)) as $b
  | ($b | map(startswith("## 6. Review — user")) | rindex(true)) as $review
  | ($c | to_entries | map(select(.value.bot == false))
       | (if length == 0 then null else last.key end)) as $person
  | ([$review, $person] | map(select(. != null))
       | if length == 0 then -1 else max end) as $i
  | $b[$i + 1:]
  | [.[] | split("\n")[0] | select(startswith("## ") and contains("— " + $name))] | length')
echo "$NAME has run $RUNS time(s) on #$NUM"

# hq#78 R5: a build run is a rebuild-after-QA-fail if the most recent QA ❌ comment
# is more recent than the most recent build-stage comment. claude-args.sh reads this
# to escalate that one run to opus/high, overriding builder.md's own frontmatter.
if [ "$NAME" = builder ]; then
  ESCALATE=$(echo "$COMMENTS" | jq '[.[].body] as $b
          | ($b | map(startswith("## ") and contains("— qa ❌")) | rindex(true)) as $qa
          | ($b | map(startswith("## ") and contains("— builder")) | rindex(true)) as $build
          | ($qa != null and ($build == null or $qa > $build))')
  echo "$ESCALATE" > "${RUNNER_TEMP:-/tmp}/hq-rebuild-escalate"
  echo "rebuild escalation for #$NUM: $ESCALATE"
fi

if [ "$RUNS" -ge 3 ]; then
  # The label an agent runs on is the inverse of which-agent.sh's NAME lookup.
  case "$NAME" in
    planner) STAGE=plan ;;
    builder) STAGE=build ;;
    *) STAGE="$NAME" ;;
  esac
  # GITHUB_TOKEN label changes don't trigger workflows, so assign here too.
  gh issue edit "$NUM" --repo "$GITHUB_REPOSITORY" --add-label waiting:user \
    --add-assignee "$GITHUB_REPOSITORY_OWNER"
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" --body \
    "🛑 Stopped: **$NAME** has run 3 times on this Work Item. Something upstream is unresolved, so a person needs to look. To let it continue: 1) comment on this Issue (anything, e.g. \`go\`); 2) remove \`waiting:user\`; 3) remove \`stage:$STAGE\` and add it back. Runs before your comment don't count."
  exit 1
fi
