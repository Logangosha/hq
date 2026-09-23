#!/usr/bin/env bash
# Runs after every stage agent, whether it finished or failed. The place for anything
# that looks back at the run (cost, turns, model). It must never fail the job — the
# workflow step is continue-on-error, and this script should still exit 0.
# Usage: NUM=29 NAME=builder LABEL=stage:build OUTCOME=success \
#        EXECUTION_FILE=/path/to/execution.json bash .hq/scripts/runner/after-run.sh
# EXECUTION_FILE is claude-code-action's run log; it may be empty if the run crashed.
# Posts one comment per run (never edits an earlier one) with the metrics in plain
# text and as a hidden `<!-- hq-run {...} -->` JSON block. Always exits 0: a missing,
# empty or unparsable execution file just means the metrics come out "unknown", not a
# failed job. Same code path for every stage — nothing here branches on it.
# If the Issue's `stage:` label hasn't moved (still just $LABEL), the run's final
# message is posted as a quoted comment and the item is parked with `waiting:user` —
# no more waiting on the 15-minute stall notice to notice a silent agent.
set -uo pipefail

: "${NUM:?}" "${NAME:?}" "${LABEL:?}" "${OUTCOME:?}"

STAGE="${LABEL#stage:}"
MODEL="unknown"
EFFORT="unknown"
TURNS="unknown"
INPUT_TOKENS="unknown"
OUTPUT_TOKENS="unknown"
CACHE_TOKENS="unknown"
COST="unknown"
RESULT=""

if [ -n "${EXECUTION_FILE:-}" ] && [ -s "$EXECUTION_FILE" ] && jq -e . "$EXECUTION_FILE" >/dev/null 2>&1; then
  MODEL="$(jq -r '[.[] | select(.type == "system" and .subtype == "init")] | last | .model // "unknown"' "$EXECUTION_FILE" 2>/dev/null)" || MODEL="unknown"
  [ -n "$MODEL" ] || MODEL="unknown"
  EFFORT="$(jq -r '[.[] | select(.type == "system" and .subtype == "init")] | last | .effort // "unknown"' "$EXECUTION_FILE" 2>/dev/null)" || EFFORT="unknown"
  [ -n "$EFFORT" ] || EFFORT="unknown"

  RESULT="$(jq -c '[.[] | select(.type == "result")] | last' "$EXECUTION_FILE" 2>/dev/null)" || RESULT=""
  if [ -n "$RESULT" ] && [ "$RESULT" != "null" ]; then
    TURNS="$(jq -r '.num_turns // "unknown"' <<<"$RESULT" 2>/dev/null)" || TURNS="unknown"
    INPUT_TOKENS="$(jq -r '.usage.input_tokens // "unknown"' <<<"$RESULT" 2>/dev/null)" || INPUT_TOKENS="unknown"
    OUTPUT_TOKENS="$(jq -r '.usage.output_tokens // "unknown"' <<<"$RESULT" 2>/dev/null)" || OUTPUT_TOKENS="unknown"
    CACHE_TOKENS="$(jq -r '((.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)) | tostring' <<<"$RESULT" 2>/dev/null)" || CACHE_TOKENS="unknown"
    COST="$(jq -r '.total_cost_usd // "unknown"' <<<"$RESULT" 2>/dev/null)" || COST="unknown"
    [ -n "$TURNS" ] || TURNS="unknown"
    [ -n "$INPUT_TOKENS" ] || INPUT_TOKENS="unknown"
    [ -n "$OUTPUT_TOKENS" ] || OUTPUT_TOKENS="unknown"
    [ -n "$CACHE_TOKENS" ] || CACHE_TOKENS="unknown"
    [ -n "$COST" ] || COST="unknown"
  fi
fi

JSON="$(jq -n -c \
  --arg stage "$STAGE" \
  --arg model "$MODEL" \
  --arg effort "$EFFORT" \
  --arg turns "$TURNS" \
  --arg input_tokens "$INPUT_TOKENS" \
  --arg output_tokens "$OUTPUT_TOKENS" \
  --arg cache_tokens "$CACHE_TOKENS" \
  --arg cost "$COST" \
  --arg outcome "$OUTCOME" \
  '{stage: $stage, model: $model, effort: $effort, turns: $turns, input_tokens: $input_tokens, output_tokens: $output_tokens, cache_tokens: $cache_tokens, cost: $cost, outcome: $outcome}')"

BODY_FILE="$(mktemp)"
{
  echo "Stage: $STAGE"
  echo "Model: $MODEL"
  echo "Effort: $EFFORT"
  echo "Turns: $TURNS"
  echo "Input tokens: $INPUT_TOKENS"
  echo "Output tokens: $OUTPUT_TOKENS"
  echo "Cache tokens: $CACHE_TOKENS"
  echo "Cost (\$): $COST"
  echo "Outcome: $OUTCOME"
  echo "<!-- hq-run $JSON -->"
} > "$BODY_FILE"

gh issue comment "$NUM" --repo "${GITHUB_REPOSITORY:?}" --body-file "$BODY_FILE" \
  || echo "after-run: failed to post comment for #$NUM" >&2

rm -f "$BODY_FILE"

STAGE_LABELS="$(gh issue view "$NUM" --repo "${GITHUB_REPOSITORY:?}" --json labels 2>/dev/null \
  | jq -c '[.labels[].name | select(startswith("stage:"))]' 2>/dev/null)"

if [ -z "$STAGE_LABELS" ]; then
  echo "after-run: could not read stage labels for #$NUM, skipping park check" >&2
elif jq -e --arg l "$LABEL" '. == [$l]' <<<"$STAGE_LABELS" >/dev/null 2>&1; then
  FINAL="$(jq -r '.result // empty | strings' <<<"$RESULT" 2>/dev/null)"
  if [ -z "$FINAL" ]; then
    FINAL="(No final message — the execution file was missing, empty, unreadable or had no result.)"
  fi

  PARK_FILE="$(mktemp)"
  {
    echo "🛑 The **$NAME** agent finished but the stage didn't move (\`$LABEL\` is still set). Parked with \`waiting:user\` — its final message is below."
    echo
    while IFS= read -r line; do
      echo "> $line"
    done <<<"$FINAL"
  } > "$PARK_FILE"

  CAPPED="$(jq -Rrs '{body: .[0:65000], cut: (length > 65000)}' "$PARK_FILE")"
  jq -r '.body' <<<"$CAPPED" > "$PARK_FILE"
  if [ "$(jq -r '.cut' <<<"$CAPPED")" = "true" ]; then
    printf '\n\n_(truncated)_' >> "$PARK_FILE"
  fi

  gh issue comment "$NUM" --repo "${GITHUB_REPOSITORY:?}" --body-file "$PARK_FILE" \
    || echo "after-run: failed to post final-message comment for #$NUM" >&2
  gh issue edit "$NUM" --repo "${GITHUB_REPOSITORY:?}" --add-label waiting:user --add-assignee "${GITHUB_REPOSITORY_OWNER:-}" \
    || echo "after-run: failed to park #$NUM with waiting:user" >&2

  rm -f "$PARK_FILE"
fi

exit 0
