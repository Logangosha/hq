#!/usr/bin/env bash
# Start a workflow run (the /run skill's stage 5, for a workflow). Ask text on stdin.
# Usage: printf '%s' "$ASK" | bash scripts/flow-start.sh <owner/repo> <workflow>
# Opens the run's Issue (flow:<wf>, step:<start>), then starts its first stage.
# Prints issue=<url>.
# Exit codes: 0 ok. 1 bad usage. 3 no such workflow. 6 the workflow has no `trigger` item.
# 8 a view-only workflow (a Work Item workflow, or Started by without `user`).
# 9 a skill or workflow stage in the run whose card Uses doesn't list the workflow.
# 7 an agent run (HQ_RUN_AGENT set) that doesn't list the workflow in its `workflows:`.
# HQ_TRIGGER="<name> <stamp> <cron>" (set by runner/schedule.sh) skips the 8 check and
# names the schedule trigger on the Issue. HQ_EVENT="<name> <issue> label:<x>" (set by
# runner/event.sh) does the same for an event trigger; the ask is on stdin.
set -euo pipefail

REPO="${1:-}"; WF="${2:-}"
if [ -z "$REPO" ] || [ -z "$WF" ]; then
  echo "Usage: printf '%s' \"\$ASK\" | bash scripts/flow-start.sh <owner/repo> <workflow>" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${HQ_RUN_AGENT:-}" ] && [[ ",${HQ_RUN_WORKFLOWS:-}," != *",$WF,"* ]]; then
  echo "Workflow $WF isn't on $HQ_RUN_AGENT's list; this run may not start it." >&2
  exit 7
fi
# shellcheck source=runner/uses-lib.sh
. "$HERE/scripts/runner/uses-lib.sh"
uses_check workflow "$WF" || exit 9

# shellcheck source=lib/flow-fetch.sh
. "$HERE/scripts/lib/flow-fetch.sh"
# shellcheck source=runner/flow-lib.sh
. "$HERE/scripts/runner/flow-lib.sh"
# shellcheck source=runner/trigger-lib.sh
. "$HERE/scripts/runner/trigger-lib.sh"

ASK="$(cat; printf x)"; ASK="${ASK%x}"

FILE="$(mktemp)"
trap 'rm -f "$FILE"' EXIT
flow_fetch "$REPO" "$WF" "$FILE" >/dev/null || { echo "No workflow named $WF in $REPO or in HQ." >&2; exit 3; }

if flow_is_work_item "$WF"; then
  echo "$WF is the Work Item lifecycle — use the new-work-item skill (agents: scripts/work-item-start.sh)." >&2
  exit 8
fi
if [ -z "${HQ_RUN_AGENT:-}" ] && [ -z "${HQ_TRIGGER:-}" ] && [ -z "${HQ_EVENT:-}" ]; then
  case ",$(card_started_by "$FILE" | tr -d ' ')," in
    *,user,*) ;;
    *) echo "$WF is view only (its Started by doesn't include user)." >&2; exit 8 ;;
  esac
fi

START="$(flow_start_of "$FILE" trigger)"
[ -n "$START" ] || { echo "Workflow $WF has no Items row made by trigger." >&2; exit 6; }

flow_label "$REPO" "flow:$WF"
flow_label "$REPO" "step:$START"

BODY_FILE="$(mktemp)"
printf 'Workflow: %s\n\nAsk:\n\n%s\n' "$WF" "$ASK" > "$BODY_FILE"
if [ -n "${HQ_TRIGGER:-}" ]; then
  read -r T_NAME T_STAMP T_CRON <<<"$HQ_TRIGGER"
  printf '\n---\nStarted from trigger `%s` (schedule `%s`, due %s)\n<!-- hq-trigger %s %s -->\n' \
    "$T_NAME" "$T_CRON" "$T_STAMP" "$T_NAME" "$T_STAMP" >> "$BODY_FILE"
fi
if [ -n "${HQ_EVENT:-}" ]; then
  read -r E_NAME E_NUM E_WHEN <<<"$HQ_EVENT"
  printf '\n---\nStarted from trigger `%s` (event `%s` on #%s)\n<!-- hq-event %s #%s -->\n' \
    "$E_NAME" "$E_WHEN" "$E_NUM" "$E_NAME" "$E_NUM" >> "$BODY_FILE"
fi
URL="$(gh issue create --repo "$REPO" \
  --title "$WF: $(printf '%s' "$ASK" | head -1 | cut -c1-60)" \
  --label "flow:$WF" --label "step:$START" --body-file "$BODY_FILE")"
rm -f "$BODY_FILE"

flow_arrive "$REPO" "${URL##*/}" "$FILE" "$START"
echo "issue=$URL"
