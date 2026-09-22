# shellcheck shell=bash
# Goal completeness check (R1-R7): a goal is complete once it has a non-empty
# "Current state" and a non-empty "Desired state" part. Plain bash string ops only
# (no perl/GNU-grep), so this runs on a user's local macOS bash too.
# Usage: source scripts/lib/goal-check.sh

_goal_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Pulls the text after "**<marker>:**" up to the next "**" marker (or end of
# string) out of a goal body. Empty if the marker isn't present.
_goal_part() {  # body, marker (e.g. "Current state")
  local body="$1" marker="$2" rest
  case "$body" in
    *"**$marker:**"*)
      rest="${body#*"**$marker:**"}"
      printf '%s' "${rest%%\*\**}"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

# Reads a goal body on stdin (the "## Goal" body, or the stdin form's raw
# markdown). Prints one line per missing part ("current state", "desired
# state"); prints nothing if both are present and non-empty.
goal_missing_parts() {
  local body current desired
  body="$(cat)"
  current="$(_goal_part "$body" "Current state")"
  desired="$(_goal_part "$body" "Desired state")"
  [ -z "$(_goal_trim "$current")" ] && echo "current state"
  [ -z "$(_goal_trim "$desired")" ] && echo "desired state"
  return 0
}

# Joins missing-part lines (as produced by goal_missing_parts, on stdin) into
# a human-readable phrase, e.g. "current state" or "current state and desired
# state". Empty if nothing is missing.
goal_join_missing() {
  local parts=() line
  # `|| [ -n "$line" ]` also picks up a final line with no trailing newline —
  # command substitution strips it, and a plain `while read` would drop it.
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] && parts+=("$line")
  done
  case "${#parts[@]}" in
    0) return 0 ;;
    1) printf '%s' "${parts[0]}" ;;
    *) printf '%s and %s' "${parts[0]}" "${parts[1]}" ;;
  esac
}
