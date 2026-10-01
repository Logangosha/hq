#!/usr/bin/env bash
# PreToolUse / PostToolUse hook on the Skill tool (hq#273). On a runner run, the caller is
# the top of a stack (USES_SKILL_FILE). PreToolUse: pops back below the skill if it is
# already on the stack (a re-call), refuses it if the new top's card Uses doesn't list it
# (exit 2 blocks the call; the stack is untouched), else pushes it. PostToolUse: pops a
# `context: fork` skill when its call returns. Does nothing outside a runner run
# (HQ_RUN_AGENT unset).
set -uo pipefail
[ -n "${HQ_RUN_AGENT:-}" ] || exit 0
command -v jq >/dev/null || { echo "uses-hook: jq missing; refusing Skill calls." >&2; exit 2; }
IN="$(cat)"
[ "$(jq -r '.tool_name // empty' <<<"$IN")" = Skill ] || exit 0
EVENT="$(jq -r '.hook_event_name // "PreToolUse"' <<<"$IN")"
SKILL="$(jq -r '.tool_input.skill // empty' <<<"$IN")"
SKILL="${SKILL##*:}"
# shellcheck source=uses-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/uses-lib.sh"
STACK=()
[ -f "$USES_SKILL_FILE" ] && mapfile -t STACK < "$USES_SKILL_FILE"
NEW=("${STACK[@]}")
FOUND=0
for i in "${!STACK[@]}"; do
  if [ "${STACK[$i]}" = "$SKILL" ]; then NEW=("${STACK[@]:0:$i}"); FOUND=1; break; fi
done
write_stack() { if [ $# -gt 0 ]; then printf '%s\n' "$@" > "$USES_SKILL_FILE"; else : > "$USES_SKILL_FILE"; fi; }
if [ "$EVENT" = PostToolUse ]; then
  if [ "$FOUND" = 1 ] && uses_forked "$SKILL"; then write_stack "${NEW[@]}"; fi
  exit 0
fi
TOP=""
[ "${#NEW[@]}" -gt 0 ] && TOP="${NEW[${#NEW[@]}-1]}"
uses_check skill "$SKILL" "$TOP" || exit 2
if [[ ",${HQ_RUN_SKILLS:-}," == *",$SKILL,"* ]]; then
  write_stack "${NEW[@]}" "$SKILL"
fi
exit 0
