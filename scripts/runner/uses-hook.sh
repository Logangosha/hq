#!/usr/bin/env bash
# PreToolUse hook on the Skill tool (hq#273). On a runner run: refuses a skill the
# caller's card Uses doesn't list (exit 2 blocks the call), then records the skill as
# the new caller. Does nothing outside a runner run (HQ_RUN_AGENT unset).
set -uo pipefail
[ -n "${HQ_RUN_AGENT:-}" ] || exit 0
command -v jq >/dev/null || { echo "uses-hook: jq missing; refusing Skill calls." >&2; exit 2; }
IN="$(cat)"
[ "$(jq -r '.tool_name // empty' <<<"$IN")" = Skill ] || exit 0
SKILL="$(jq -r '.tool_input.skill // empty' <<<"$IN")"
SKILL="${SKILL##*:}"
# shellcheck source=uses-lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/uses-lib.sh"
uses_check skill "$SKILL" || exit 2
if [[ ",${HQ_RUN_SKILLS:-}," == *",$SKILL,"* ]]; then
  printf '%s' "$SKILL" > "$USES_SKILL_FILE"
fi
exit 0
