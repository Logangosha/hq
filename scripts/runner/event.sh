#!/usr/bin/env bash
# The event hook: start the target of every `event` trigger in this repo whose When is
# `label:<name>` for the label an Issue just got (orchestration/contract.md, "Triggers").
# Run by the runner's `event` job when an Issue is labelled, from the repo's checkout with
# HQ at .hq/. Reads only this repo's triggers/.
# Env: GITHUB_REPOSITORY, GH_TOKEN, NUM (the labelled Issue), LABEL (the label's name).
# Loop guard: an Issue an event run opened (or a flow step Issue made by one) carries
# `<!-- hq-event `; labels on those fire nothing.
set -euo pipefail

: "${GITHUB_REPOSITORY:?}" "${NUM:?}" "${LABEL:?}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flow-lib.sh
. "$HERE/flow-lib.sh"
# shellcheck source=trigger-lib.sh
. "$HERE/trigger-lib.sh"

FOUND=0
for F in triggers/*.md; do
  [ -f "$F" ] && [ "$F" != triggers/README.md ] && FOUND=1
done
[ "$FOUND" = 1 ] || { echo "no triggers"; exit 0; }

# Guard: follow `Made by #M at` up to 10 hops looking for an event marker.
CUR="$NUM"; URL=""
for ((hop = 0; hop < 10; hop++)); do
  JSON="$(gh issue view "$CUR" --repo "$GITHUB_REPOSITORY" --json body,url)"
  BODY="$(jq -r '.body // ""' <<<"$JSON")"
  [ -n "$URL" ] || URL="$(jq -r '.url' <<<"$JSON")"
  if grep -qF -- '<!-- hq-event ' <<<"$BODY"; then echo "skip: #$NUM is part of an event run"; exit 0; fi
  PARENT="$(grep -o 'Made by #[0-9]* at' <<<"$BODY" | head -1 | grep -o '[0-9]*' || true)"
  [ -n "$PARENT" ] || break
  CUR="$PARENT"
done

for F in triggers/*.md; do
  [ -f "$F" ] && [ "$F" != triggers/README.md ] || continue
  NAME="$(basename "$F" .md)"
  T_kind=""; T_target=""; T_when=""; T_ask=""; T_error=""
  while IFS='=' read -r K V; do
    case "$K" in kind) T_kind="$V" ;; target) T_target="$V" ;; when) T_when="$V" ;; ask) T_ask="$V" ;; error) T_error="$V" ;; esac
  done < <(trigger_read "$F" "$NAME")

  [ "$T_kind" = event ] || continue
  if [ -n "$T_error" ]; then echo "skip $NAME: $T_error"; continue; fi
  [ "$T_when" = "label:$LABEL" ] || continue
  TF="$(trigger_target_file "$T_target")" || { echo "skip $NAME: no such target $T_target"; continue; }
  case ",$(card_started_by "$TF" | tr -d ' ')," in
    *,event,*) ;;
    *) echo "skip $NAME: $T_target isn't started by event"; continue ;;
  esac

  ASK="$(printf 'Issue #%s: %s (got label `%s`)' "$NUM" "$URL" "$LABEL")"
  [ -z "$T_ask" ] || ASK="$(printf '%s\n\n%s' "$ASK" "$T_ask")"
  FOOT="Started from trigger \`$NAME\` (event \`$T_when\` on #$NUM)"
  MARK="<!-- hq-event $NAME #$NUM -->"
  KIND="${T_target%%:*}"; TNAME="${T_target#*:}"
  echo "fire $NAME: $T_target on #$NUM"
  if [ "$KIND" = workflow ]; then
    printf '%s' "$ASK" | HQ_EVENT="$NAME $NUM $T_when" bash "$HERE/../flow-start.sh" "$GITHUB_REPOSITORY" "$TNAME"
  else
    if [ "$KIND" = skill ]; then AGENT=skill-runner; RUN_ASK="$(printf 'skill:%s\n\n%s' "$TNAME" "$ASK")"
    else AGENT="$TNAME"; RUN_ASK="$ASK"; fi
    flow_label "$GITHUB_REPOSITORY" run
    RUN_URL="$(gh issue create --repo "$GITHUB_REPOSITORY" --label run \
      --title "Event: $NAME — $AGENT" \
      --body "$(printf 'Agent: %s\n\nAsk:\n\n%s\n\n---\n%s\n%s\n' "$AGENT" "$RUN_ASK" "$FOOT" "$MARK")")"
    N="${RUN_URL##*/}"
    if ! gh workflow run work-item.yml -R "$GITHUB_REPOSITORY" -f agent="$AGENT" -f ask="hq-issue $N" >/dev/null; then
      gh issue comment "$N" --repo "$GITHUB_REPOSITORY" --body "🛑 Couldn't start $AGENT from trigger \`$NAME\`." || true
    fi
  fi
done
