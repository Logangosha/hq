#!/usr/bin/env bash
# Prints an agent file's `skills:` or `workflows:` frontmatter value as a no-space comma
# list (e.g. `work-items,review`). Prints nothing if the file has no such line. Entries
# that aren't a plain name (lowercase letters, digits, hyphens) are dropped.
# Usage: bash scripts/runner/agent-access.sh <agent-file> skills|workflows
set -euo pipefail

AGENT_FILE="${1:?usage: agent-access.sh <agent-file> skills|workflows}"
FIELD="${2:?usage: agent-access.sh <agent-file> skills|workflows}"
case "$FIELD" in skills|workflows) ;; *) echo "field must be skills or workflows" >&2; exit 1 ;; esac

FRONTMATTER="$(sed -n '/^---$/,/^---$/p' "$AGENT_FILE")"
LINE="$(sed -n "s/^$FIELD: *//p" <<<"$FRONTMATTER" | head -1)"
tr ',' '\n' <<<"$LINE" | tr -d ' \r' | grep -E '^[a-z0-9][a-z0-9-]*$' | paste -sd, - || true
