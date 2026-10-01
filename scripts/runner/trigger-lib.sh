#!/usr/bin/env bash
# Sourced helpers for trigger files (orchestration/contract.md, "Triggers"): reading and
# checking one, cron matching, and finding a trigger's target. Bash, awk and date only.
# Needs flow-lib.sh sourced first (flow_rows, flow_file).

TRIGGER_NAME_RE='^[a-z0-9][a-z0-9-]*$'
TRIGGER_TARGET_RE='^(skill|agent|workflow):[A-Za-z0-9][A-Za-z0-9_-]*$'

# _utc_fmt <epoch> <format> — GNU date, else BSD date.
_utc_fmt() { date -u -d "@$1" "+$2" 2>/dev/null || date -u -r "$1" "+$2"; }

# _cron_field_ok <field> <min> <max> — one cron field: a comma list of *, a, a-b, */s, a-b/s.
_cron_field_ok() {
  local item items range step lo hi
  read -ra items <<<"${1//,/ }"
  [ "${#items[@]}" -gt 0 ] && [[ "$1" != ,* && "$1" != *, && "$1" != *,,* ]] || return 1
  for item in "${items[@]}"; do
    range="${item%%/*}"; step=""
    [[ "$item" == */* ]] && step="${item#*/}"
    [[ "$item" == */*/* ]] && return 1
    if [ -n "$step" ]; then [[ "$step" =~ ^[0-9]+$ ]] && [ "$((10#$step))" -ge 1 ] || return 1; fi
    if [ "$range" = '*' ]; then continue
    elif [[ "$range" =~ ^[0-9]+$ ]]; then lo="$range"; hi="$range"
    elif [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then lo="${BASH_REMATCH[1]}"; hi="${BASH_REMATCH[2]}"
    else return 1; fi
    [ "$((10#$lo))" -ge "$2" ] && [ "$((10#$hi))" -le "$3" ] && [ "$((10#$lo))" -le "$((10#$hi))" ] || return 1
  done
  return 0
}

# cron_valid <expr> — five numeric fields: minute hour day-of-month month day-of-week (0-7).
cron_valid() {
  local f
  read -ra f <<<"$1"
  [ "${#f[@]}" -eq 5 ] || return 1
  _cron_field_ok "${f[0]}" 0 59 && _cron_field_ok "${f[1]}" 0 23 && _cron_field_ok "${f[2]}" 1 31 \
    && _cron_field_ok "${f[3]}" 1 12 && _cron_field_ok "${f[4]}" 0 7
}

# _cron_field_match <field> <value> <min> — does <value> satisfy the field?
_cron_field_match() {
  local item items range step lo hi
  read -ra items <<<"${1//,/ }"
  for item in "${items[@]}"; do
    range="${item%%/*}"; step=1
    [[ "$item" == */* ]] && step="$((10#${item#*/}))"
    if [ "$range" = '*' ]; then lo="$3"; hi=99
    elif [[ "$range" =~ ^[0-9]+$ ]]; then lo="$((10#$range))"; hi="$lo"
      [[ "$item" == */* ]] && hi=99
    else lo="$((10#${range%-*}))"; hi="$((10#${range#*-}))"; fi
    if [ "$2" -ge "$lo" ] && [ "$2" -le "$hi" ] && [ $(( ($2 - lo) % step )) -eq 0 ]; then return 0; fi
  done
  return 1
}

# cron_match <expr> <epoch> — does the (UTC) minute of <epoch> match? Day-of-month and
# day-of-week are ORed when both are restricted, as in cron.
cron_match() {
  local f mi h d mo w dom_ok dow_ok
  read -ra f <<<"$1"
  read -r mi h d mo w <<<"$(_utc_fmt "$2" '%M %H %d %m %w')"
  _cron_field_match "${f[0]}" "$((10#$mi))" 0 || return 1
  _cron_field_match "${f[1]}" "$((10#$h))" 0 || return 1
  _cron_field_match "${f[3]}" "$((10#$mo))" 1 || return 1
  dom_ok=1; dow_ok=1
  _cron_field_match "${f[2]}" "$((10#$d))" 1 || dom_ok=0
  # day-of-week 7 is Sunday too
  _cron_field_match "${f[4]}" "$w" 0 || { [ "$w" = 0 ] && _cron_field_match "${f[4]}" 7 0; } || dow_ok=0
  if [ "${f[2]}" != '*' ] && [ "${f[4]}" != '*' ]; then
    [ "$dom_ok" = 1 ] || [ "$dow_ok" = 1 ]
  else
    [ "$dom_ok" = 1 ] && [ "$dow_ok" = 1 ]
  fi
}

# cron_due <expr> <now-epoch> <window-minutes> — the latest matching minute (epoch) in
# (now - window, now], or nothing.
cron_due() {
  local t i
  t=$(( $2 - $2 % 60 ))
  for ((i = 0; i < $3; i++)); do
    if cron_match "$1" "$t"; then printf '%s\n' "$t"; return 0; fi
    t=$((t - 60))
  done
  return 1
}

# trigger_read <file> <name> — prints kind=, target=, when=, ask=, error= (one line each).
# error= is empty when the trigger is valid.
trigger_read() {
  local file="$1" name="$2" rows kind="" target="" when="" ask="" err="" nk=0 nt=0 nw=0 na=0
  local field value
  if ! [[ "$name" =~ $TRIGGER_NAME_RE ]]; then err="bad trigger name \`$name\`"; fi
  rows="$(awk '/^\|/ { n++; if (n > 2) { gsub(/`/, ""); split($0, c, "|");
      f = c[2]; v = c[3]; for (i = 4; i < length(c); i++) v = v "|" c[i];
      gsub(/^ +| +$/, "", f); gsub(/^ +| +$/, "", v); print f "\t" v } }' "$file")"
  while IFS=$'\t' read -r field value; do
    [ -n "$field" ] || continue
    case "$field" in
      Kind) kind="$value"; nk=$((nk + 1)) ;;
      Target) target="$value"; nt=$((nt + 1)) ;;
      When) when="$value"; nw=$((nw + 1)) ;;
      Ask) ask="$value"; na=$((na + 1)) ;;
      Field) ;;
      *) [ -n "$err" ] || err="unknown field \`$field\`" ;;
    esac
  done <<<"$rows"
  [ -n "$err" ] || { [ "$nk" -le 1 ] && [ "$nt" -le 1 ] && [ "$nw" -le 1 ] && [ "$na" -le 1 ] || err="a field is given twice"; }
  if [ -z "$err" ]; then
    case "$kind" in
      manual|schedule|event) ;;
      "") err="no Kind (manual, schedule or event)" ;;
      *) err="bad Kind \`$kind\` (manual, schedule or event)" ;;
    esac
  fi
  if [ -z "$err" ]; then
    if [ -z "$target" ]; then err="no Target"
    elif [[ "$target" == *[,\ ]* ]]; then err="more than one target — a trigger has exactly one"
    elif ! [[ "$target" =~ $TRIGGER_TARGET_RE ]]; then err="bad Target \`$target\` (skill:<name>, agent:<name> or workflow:<name>)"; fi
  fi
  if [ -z "$err" ]; then
    case "$kind" in
      schedule)
        if [ -z "$when" ] || [ "$when" = "—" ]; then err="a schedule needs a cron in When"
        elif ! cron_valid "$when"; then err="bad cron \`$when\`"; fi ;;
      event)
        { [ -n "$when" ] && [ "$when" != "—" ]; } || err="an event trigger needs an event name in When" ;;
      manual)
        if [ -n "$when" ] && [ "$when" != "—" ] && [ "$when" != "-" ]; then err="a manual trigger takes no When"; fi ;;
    esac
  fi
  [ "$when" = "—" ] && when=""
  [ "$ask" = "—" ] && ask=""
  printf 'kind=%s\ntarget=%s\nwhen=%s\nask=%s\nerror=%s\n' "$kind" "$target" "$when" "$ask" "$err"
}

# card_started_by <file> — the `## Card` Started by value; missing = user.
card_started_by() {
  local v
  v="$(flow_rows "$1" Card | awk -F'\t' '$1 == "Started by" { print $2; exit }')"
  printf '%s\n' "${v:-user}"
}

# trigger_target_file <target> — the file of an existing target, else fails.
# Own repo first, then HQ's copy at .hq/ (skills marked `hq-only: true` stay in HQ).
trigger_target_file() {
  local kind="${1%%:*}" n="${1#*:}" f
  case "$kind" in
    agent) for f in ".claude/agents/$n.md" ".hq/.claude/agents/$n.md"; do [ -f "$f" ] && { echo "$f"; return 0; }; done ;;
    skill)
      [ -f ".claude/skills/$n/SKILL.md" ] && { echo ".claude/skills/$n/SKILL.md"; return 0; }
      f=".hq/.claude/skills/$n/SKILL.md"
      [ -f "$f" ] && ! grep -q '^hq-only: *true' "$f" && { echo "$f"; return 0; } ;;
    workflow) flow_file "$n" && return 0 ;;
  esac
  return 1
}
