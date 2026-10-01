#!/usr/bin/env bash
# Sourced. Enforces a skill's or workflow's card `Uses` on a runner run (hq#273).
# USES_SKILL_FILE holds the name of the skill most recently started in this run (the
# caller); uses-hook.sh writes it. HQ_FLOW_WF / HQ_FLOW_USES are the workflow of a
# workflow stage run and its Uses (claude-args.sh writes them).
USES_SKILL_FILE="${RUNNER_TEMP:-/tmp}/hq-uses-skill"

# The card's Uses row as a no-space comma list. Empty if the file, the Card or the row is
# missing, the value is `none`, or any item is malformed (same rule as agent-cards.py).
uses_card() {
  local val
  [ -f "$1" ] || return 0
  val="$(awk '
    /^## /{ card = ($0 ~ /^## Card[ \t]*$/); next }
    card && /^\|/ {
      n = split($0, c, "|")
      k = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", k)
      if (k == "Uses" && n >= 3) { v = c[3]; gsub(/[ \t]+/, "", v); print v; exit }
    }' "$1")"
  [ -n "$val" ] && [ "$val" != none ] || return 0
  local item
  while IFS= read -r item; do
    [[ "$item" =~ ^(skill|agent|workflow):[a-z0-9][a-z0-9-]*$ ]] || return 0
  done < <(tr ',' '\n' <<<"$val")
  printf '%s\n' "$val"
}

# The SKILL.md a run uses for a skill: the repo's own wins over HQ's.
uses_skill_md() {
  local b="${GITHUB_WORKSPACE:-$PWD}"
  if [ -f "$b/.claude/skills/$1/SKILL.md" ]; then echo "$b/.claude/skills/$1/SKILL.md"
  else echo "$b/.hq/.claude/skills/$1/SKILL.md"; fi
}

# uses_check <skill|agent|workflow> <name>: 0 if the run may call it. Every check that
# applies must pass; each only narrows.
uses_check() {
  local kind="$1" name="$2" caller list
  [ -n "${HQ_RUN_AGENT:-}" ] || return 0
  caller="$(cat "$USES_SKILL_FILE" 2>/dev/null || true)"
  if [ -n "$caller" ]; then
    list="$(uses_card "$(uses_skill_md "$caller")")"
    if [[ ",$list," != *",$kind:$name,"* ]]; then
      echo "Skill $caller's Uses doesn't list $kind:$name; this run may not call it." >&2
      return 1
    fi
  fi
  if [ -n "${HQ_FLOW_WF:-}" ] && [[ ",${HQ_FLOW_USES:-}," != *",$kind:$name,"* ]]; then
    echo "Workflow $HQ_FLOW_WF's Uses doesn't list $kind:$name; this run may not call it." >&2
    return 1
  fi
  return 0
}
