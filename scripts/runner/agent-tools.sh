#!/usr/bin/env bash
# Prints an agent file's `tools:` frontmatter value as a no-space comma list
# (e.g. `Bash,Read,Glob`). Prints nothing if the file has no `tools:` line.
# With --read-only, exits 0 only if that list is non-empty and has no `Write`
# or `Edit` entry (exact match); exits 1 otherwise.
# Usage: bash scripts/runner/agent-tools.sh <agent-file> [--read-only]
set -euo pipefail

AGENT_FILE="${1:?usage: agent-tools.sh <agent-file> [--read-only]}"
MODE="${2:-}"

FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$AGENT_FILE")"
TOOLS_LINE="$(sed -n 's/^tools: *//p' <<<"$FRONTMATTER" | head -1)"
TOOLS="$(tr -d ' ' <<<"$TOOLS_LINE")"

if [ "$MODE" = --read-only ]; then
  [ -n "$TOOLS" ] || exit 1
  IFS=',' read -r -a TOOL_ARR <<<"$TOOLS"
  for T in "${TOOL_ARR[@]}"; do
    [ "$T" = Write ] && exit 1
    [ "$T" = Edit ] && exit 1
  done
  exit 0
fi

printf '%s\n' "$TOOLS"
