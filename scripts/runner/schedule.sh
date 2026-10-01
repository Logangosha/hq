#!/usr/bin/env bash
# The schedule tick: start the target of every due `schedule` trigger in this repo
# (orchestration/contract.md, "Triggers"). Run hourly by the stub's `schedule` job, from
# the repo's checkout with HQ at .hq/. Each cron time fires once: the run Issue carries
# `<!-- hq-trigger <name> <stamp> -->`, and a time whose marker is already on a recent
# Issue is skipped.
# Env: GITHUB_REPOSITORY, GH_TOKEN. Tests: NOW=<epoch> overrides the clock; WINDOW_MIN
# (default 120) is how late a run may start.
set -euo pipefail

: "${GITHUB_REPOSITORY:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
# shellcheck source=trigger-lib.sh
. "$HERE/trigger-lib.sh"

NOW="${NOW:-$(date +%s)}"
WINDOW="${WINDOW_MIN:-120}"
RECENT=""
RECENT_LOADED=0

for F in triggers/*.md; do
  [ -f "$F" ] && [ "$F" != triggers/README.md ] || continue
  NAME="$(basename "$F" .md)"
  T_kind=""; T_target=""; T_when=""; T_ask=""; T_error=""
  while IFS='=' read -r K V; do
    case "$K" in kind) T_kind="$V" ;; target) T_target="$V" ;; when) T_when="$V" ;; ask) T_ask="$V" ;; error) T_error="$V" ;; esac
  done < <(trigger_read "$F" "$NAME")

  [ "$T_kind" = schedule ] || continue
  if [ -n "$T_error" ]; then echo "skip $NAME: $T_error"; continue; fi
  TF="$(trigger_target_file "$T_target")" || { echo "skip $NAME: no such target $T_target"; continue; }
  case ",$(card_started_by "$TF" | tr -d ' ')," in
    *,schedule,*) ;;
    *) echo "skip $NAME: $T_target isn't started by schedule"; continue ;;
  esac
  DUE="$(cron_due "$T_when" "$NOW" "$WINDOW")" || { echo "skip $NAME: not due"; continue; }
  STAMP="$(_utc_fmt "$DUE" '%Y-%m-%dT%H:%MZ')"
  MARK="<!-- hq-trigger $NAME $STAMP -->"
  if [ "$RECENT_LOADED" = 0 ]; then
    RECENT="$(gh issue list --repo "$GITHUB_REPOSITORY" --state all --limit 100 --json body --jq '.[].body')"
    RECENT_LOADED=1
  fi
  if grep -qF -- "$MARK" <<<"$RECENT"; then echo "skip $NAME: $STAMP already started"; continue; fi

  ASK="${T_ask:-No ask given — use your defaults.}"
  FOOT="Started from trigger \`$NAME\` (schedule \`$T_when\`, due $STAMP)"
  KIND="${T_target%%:*}"; TNAME="${T_target#*:}"
  echo "fire $NAME: $T_target due $STAMP"
  if [ "$KIND" = workflow ]; then
    printf '%s' "$ASK" | HQ_TRIGGER="$NAME $STAMP $T_when" bash "$HERE/../flow-start.sh" "$GITHUB_REPOSITORY" "$TNAME"
  else
    if [ "$KIND" = skill ]; then AGENT=skill-runner; RUN_ASK="$(printf 'skill:%s\n\n%s' "$TNAME" "$ASK")"
    else AGENT="$TNAME"; RUN_ASK="$ASK"; fi
    flow_label "$GITHUB_REPOSITORY" run
    URL="$(gh issue create --repo "$GITHUB_REPOSITORY" --label run \
      --title "Scheduled: $NAME — $AGENT" \
      --body "$(printf 'Agent: %s\n\nAsk:\n\n%s\n\n---\n%s\n%s\n' "$AGENT" "$RUN_ASK" "$FOOT" "$MARK")")"
    N="${URL##*/}"
    if ! gh workflow run work-item.yml -R "$GITHUB_REPOSITORY" -f agent="$AGENT" -f ask="hq-issue $N" >/dev/null; then
      gh issue comment "$N" --repo "$GITHUB_REPOSITORY" --body "🛑 Couldn't start $AGENT from trigger \`$NAME\`." || true
    fi
  fi
  RECENT="$RECENT
$MARK"
done
