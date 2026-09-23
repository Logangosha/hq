#!/usr/bin/env bash
# Trims test and build output so a long log doesn't eat the agent's context — while
# every failure's own text survives in full (hq#79 R13).
#
# Two modes:
#   (hook)                     PreToolUse JSON on stdin. Wraps a matching Bash command
#                              so its output goes through --render. Prints nothing for
#                              anything else, which leaves that command untouched (R15).
#   --render <log> <status>    Renders a captured log. QA can run this directly.
#
# The wrapper never changes what the command returns: the agent gets the command's own
# exit status, and the summary line says FAILED whenever that status is non-zero (R16).
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

HEAD_LINES=20
TAIL_LINES=40
TRIM_ABOVE=200

# A line that starts a failure block. The block runs on to the next blank line, so a
# traceback or an assertion diff is kept whole.
FAIL_RE='(FAIL|FAILED|Error|error:|Traceback|AssertionError|panic:)'

# Conservative: test and build runners only. Anything not listed here is left alone.
TEST_RE='(^|[;&|(]|&&|\|\|)[[:space:]]*(env [^;&|]*)?((npx |npm |yarn |pnpm |bunx |poetry run |uv run |python -m |python3 -m )?(jest|vitest|mocha|pytest|tox|nox|bats|ava)\b|npm (run )?(test|build)\b|yarn (test|build)\b|pnpm (run )?(test|build)\b|go (test|build|vet)\b|cargo (test|build|check|clippy)\b|make( -[^ ]+)*( [a-zA-Z0-9_.:-]+)*\b|mvn\b|gradle\b|./gradlew\b|dotnet (test|build)\b|rspec\b|bundle exec rspec\b|ctest\b|tsc\b)'

OMIT_MARK='… %d lines of passing output omitted …\n'

render() {
  local log="$1" rc="$2" total kept out
  total="$(wc -l < "$log" | tr -d ' ')"
  if [ "$total" -le "$TRIM_ABOVE" ]; then
    cat "$log"
    kept="$total"
  else
    out="$(mktemp)"
    awk -v fail="$FAIL_RE" -v head="$HEAD_LINES" -v tail="$TAIL_LINES" -v mark="$OMIT_MARK" '
      { line[NR] = $0 }
      END {
        n = NR
        # Every failure block, whole: the matching line and on to the next blank line.
        for (i = 1; i <= n; i++) {
          if (line[i] ~ fail) {
            keep[i] = 1
            for (j = i + 1; j <= n; j++) {
              if (line[j] ~ /^[[:space:]]*$/) break
              keep[j] = 1
            }
          }
        }
        for (i = 1; i <= head && i <= n; i++) keep[i] = 1
        for (i = n - tail + 1; i <= n; i++) if (i >= 1) keep[i] = 1
        gap = 0
        for (i = 1; i <= n; i++) {
          if (keep[i]) {
            if (gap > 0) { printf mark, gap; gap = 0 }
            print line[i]
          } else gap++
        }
        if (gap > 0) printf mark, gap
      }
    ' "$log" > "$out"
    cat "$out"
    kept="$(grep -cve '^… .* omitted …$' "$out" || true)"
    rm -f "$out"
  fi
  if [ "$rc" -eq 0 ]; then
    printf -- '--- hq-trim: %s of %s lines shown · exit %s · OK ---\n' "$kept" "$total" "$rc"
  else
    printf -- '--- hq-trim: %s of %s lines shown · exit %s · FAILED ---\n' "$kept" "$total" "$rc"
  fi
}

if [ "${1:-}" = "--render" ]; then
  render "${2:?log file}" "${3:?exit status}"
  exit 0
fi

# ---- hook mode ----
INPUT="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

TOOL="$(jq -r '.tool_name // ""' <<<"$INPUT" 2>/dev/null)" || exit 0
[ "$TOOL" = "Bash" ] || exit 0

CMD="$(jq -r '.tool_input.command // ""' <<<"$INPUT" 2>/dev/null)" || exit 0
BG="$(jq -r '.tool_input.run_in_background // false' <<<"$INPUT" 2>/dev/null)" || exit 0

[ -n "$CMD" ] || exit 0
[ "$BG" != "true" ] || exit 0                 # background output isn't returned inline
case "$CMD" in *HQ_TRIM_LOG*) exit 0 ;; esac  # already wrapped
grep -Eq "$TEST_RE" <<<"$CMD" || exit 0       # not a test or build run: leave it alone

WRAPPED="HQ_TRIM_LOG=\$(mktemp)
{
$CMD
} > \"\$HQ_TRIM_LOG\" 2>&1
HQ_TRIM_RC=\$?
bash $SELF --render \"\$HQ_TRIM_LOG\" \"\$HQ_TRIM_RC\"
rm -f \"\$HQ_TRIM_LOG\"
(exit \$HQ_TRIM_RC)"

jq -n --arg c "$WRAPPED" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "output trimmed by HQ",
    updatedInput: { command: $c }
  }
}'
