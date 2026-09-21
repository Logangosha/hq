# shellcheck shell=bash
# Run a gh command, telling a GitHub refusal (rate limit, bad/expired token, no
# network) apart from every other outcome. On success, prints the command's stdout
# and returns 0, same as running it directly. On a refusal, prints
# "REFUSAL<TAB><kind><TAB><detail>" (kind is rate_limit, auth, or offline; detail is
# the rate-limit reset time, epoch seconds, or empty) and returns 2, so callers can
# forward it instead of mistaking it for an ordinary empty result. On any other
# failure, prints gh's stderr to stderr and returns 1, unchanged from today.
# Usage: gh_or_refusal gh issue list --repo owner/repo --json number
gh_or_refusal() {
  local out err_file err status kind detail
  err_file="$(mktemp)"
  out="$("$@" 2>"$err_file")"
  status=$?
  err="$(cat "$err_file")"
  rm -f "$err_file"
  if [ "$status" -eq 0 ]; then
    printf '%s\n' "$out"
    return 0
  fi
  if printf '%s' "$err" | grep -qi 'rate limit'; then
    kind="rate_limit"
    detail="$(gh api rate_limit --jq .rate.reset 2>/dev/null)"
  elif printf '%s' "$err" | grep -qiE 'bad credentials|HTTP 401|gh auth login'; then
    kind="auth"
    detail=""
  elif printf '%s' "$err" | grep -qiE 'error connecting to|check your internet connection|dial tcp'; then
    kind="offline"
    detail=""
  else
    printf '%s\n' "$err" >&2
    return 1
  fi
  printf 'REFUSAL\t%s\t%s\n' "$kind" "$detail"
  return 2
}
