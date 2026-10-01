#!/usr/bin/env bash
# Sourced. Enforces a skill's or workflow's card `Uses` on a runner run (hq#273).
# USES_SKILL_FILE is the caller stack, one skill per line, top = last line (the caller).
# uses-hook.sh pushes a started skill, pops a `context: fork` skill when it returns, and
# pops back below a skill that is called again. HQ_FLOW_WF / HQ_FLOW_USES are the workflow of a
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

# The caller: the top of the stack, empty if there is none.
uses_top() { tail -n 1 "$USES_SKILL_FILE" 2>/dev/null || true; }

# 0 if the skill's SKILL.md frontmatter says `context: fork`.
uses_forked() {
  local f
  f="$(uses_skill_md "$1")"
  [ -f "$f" ] || return 1
  awk 'NR==1 { if ($0 != "---") exit 1; next }
       /^---[ \t]*$/ { exit !found }
       /^context:[ \t]*fork[ \t]*$/ { found = 1 }
       END { exit !found }' "$f"
}

# uses_check <skill|agent|workflow> <name> [caller]: 0 if the run may call it. The caller
# defaults to the top of the stack. Every check that applies must pass; each only narrows.
uses_check() {
  local kind="$1" name="$2" caller list
  [ -n "${HQ_RUN_AGENT:-}" ] || return 0
  if [ $# -ge 3 ]; then caller="$3"; else caller="$(uses_top)"; fi
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
