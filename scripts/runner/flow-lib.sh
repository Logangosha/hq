#!/usr/bin/env bash
# Sourced helpers for running a workflow file (orchestration/workflows.md): reading its
# tables, and moving an item along its arrows. Bash, awk, sed and gh only.
# Every mover takes the workflow file path explicitly, so it works on a fetched copy.

FLOW_TMP="${RUNNER_TEMP:-/tmp}"
FLOW_STEP_FILE="$FLOW_TMP/hq-flow-step"      # num, wf, stage, agent, file of the stage being run
FLOW_MADE_FILE="$FLOW_TMP/hq-flow-made"      # numbers of Issues the stage opened
FLOW_ROUTED_FILE="$FLOW_TMP/hq-flow-routed"  # exists once the item has been moved

# flow_rows <file> <Section> — one row per line, cells tab-separated (workflows.md).
flow_rows() {
  awk -v sec="$2" '
    /^## / { on = ($0 == "## " sec); n = 0; next }
    on && /^\|/ { n++; if (n > 2) {
      gsub(/`/, ""); split($0, c, "|"); out = ""
      for (i = 2; i < length(c); i++) { gsub(/^ +| +$/, "", c[i]); out = out (i > 2 ? "\t" : "") c[i] }
      print out } }' "$1"
}

# flow_file <workflow> — the domain's workflows/<wf>.md, else HQ's (.hq/workflows/).
flow_file() {
  local f
  for f in "workflows/$1.md" ".hq/workflows/$1.md"; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

# flow_stage <file> <stage> — "kind<TAB>agent<TAB>ask"; fails if there is no such stage.
flow_stage() {
  local row
  row="$(flow_rows "$1" Stages | awk -F'\t' -v s="$2" '$1 == s { print $2 "\t" $3 "\t" $4; exit }')"
  [ -n "$row" ] || return 1
  printf '%s\n' "$row"
}

# flow_arrow <file> <from> <outcome> — the target stage, or nothing.
flow_arrow() {
  flow_rows "$1" Arrows | awk -F'\t' -v f="$2" -v o="$3" '$1 == f && $2 == o { print $3; exit }'
}

# flow_outcomes <file> <stage> — the outcomes its arrows accept, comma-separated.
flow_outcomes() {
  flow_rows "$1" Arrows | awk -F'\t' -v f="$2" '$1 == f { printf "%s%s", (n++ ? ", " : ""), $2 }'
}

# flow_start_of <file> <made-by> — where items made by `trigger` or a stage start.
flow_start_of() {
  flow_rows "$1" Items | awk -F'\t' -v m="$2" '$1 == m { print $2; exit }'
}

# flow_outcome — stdin: an agent's final message. Prints `failed` if any line starts
# `<!-- hq-run` (a runner failure notice); else its last `Outcome: <x>` line's value, or `failed`.
flow_outcome() {
  local t o
  t="$(cat)"
  if grep -q '^<!-- hq-run' <<<"$t"; then printf 'failed\n'; return; fi
  o="$(grep -iE '^[*` _]*Outcome:' <<<"$t" | tail -1 \
    | sed -E 's/^[*` _]*[Oo][Uu][Tt][Cc][Oo][Mm][Ee]:[*` ]*//; s/[*` .]*$//' \
    | tr 'A-Z' 'a-z' || true)"
  if [[ "$o" =~ ^[a-z][a-z0-9-]*$ ]]; then printf '%s\n' "$o"; else printf 'failed\n'; fi
}

# flow_label <repo> <label> — create it if missing (idempotent).
flow_label() {
  gh label create "$2" --repo "$1" --force >/dev/null 2>&1 || true
}

# flow_arrive <repo> <n> <file> <stage> — the item has reached <stage>: a gate asks the
# user and assigns the owner; an agent stage is started by dispatching the stub.
flow_arrive() {
  local repo="$1" n="$2" file="$3" stage="$4" row kind agent ask
  row="$(flow_stage "$file" "$stage")" || {
    gh issue comment "$n" --repo "$repo" --body "🛑 The workflow has no stage \`$stage\`." || true
    return 1
  }
  IFS=$'\t' read -r kind agent ask <<<"$row"
  if [ "$kind" = gate ]; then
    gh issue comment "$n" --repo "$repo" --body "**Needs you:** $ask

\`/review $repo#$n\`"
    gh issue edit "$n" --repo "$repo" --add-assignee "${repo%%/*}" >/dev/null 2>&1 || true
  else
    gh workflow run work-item.yml -R "$repo" -f agent="$agent" -f ask="hq-step $n $stage" >/dev/null
  fi
}

# flow_wait <repo> <n> <why> — park the item on waiting:user, assigned to the owner.
flow_wait() {
  gh issue comment "$2" --repo "$1" --body "$3"
  gh issue edit "$2" --repo "$1" --add-label waiting:user --add-assignee "${1%%/*}" >/dev/null 2>&1 || true
}

# flow_move <repo> <n> <file> <from> <outcome> — follow the arrow for that outcome.
flow_move() {
  local repo="$1" n="$2" file="$3" from="$4" outcome="$5" to
  to="$(flow_arrow "$file" "$from" "$outcome")"
  if [ -z "$to" ]; then
    flow_wait "$repo" "$n" "🛑 Stage \`$from\` ended with outcome \`$outcome\`, and the workflow has no arrow for it. Waiting on you."
    return 0
  fi
  if [ "$to" = end ]; then
    gh issue close "$n" --repo "$repo" --reason completed >/dev/null
    return 0
  fi
  flow_label "$repo" "step:$to"
  gh issue edit "$n" --repo "$repo" --remove-label "step:$from" --add-label "step:$to" >/dev/null
  flow_arrive "$repo" "$n" "$file" "$to"
}
