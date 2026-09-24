#!/usr/bin/env bash
# Give the stage's agent only the tools its own .claude/agents/<name>.md claims,
# not the one fixed list every stage used to share (hq#52).
# Usage: NAME=builder bash .hq/scripts/runner/tool-permissions.sh   (run from the
#        domain checkout, after install-agents.sh has put .claude/agents/ in place)
# Writes .claude/settings.local.json: allow = this agent's own tools, deny = every
# other installed agent's tools it doesn't claim. Excluded from git via
# .git/info/exclude so it can never be staged into a PR, regardless of whether the
# domain repo's own .gitignore covers it.
set -euo pipefail

: "${NAME:?NAME is required, e.g. builder}"

tools_of() {
  grep -m1 '^tools:' "$1" | cut -d: -f2- | tr ',' '\n' \
    | sed 's/^ *//; s/ *$//' | grep -v '^$'
}

mine=$(tools_of ".claude/agents/$NAME.md" | sort -u)
union=$(for f in .claude/agents/*.md; do tools_of "$f"; done | sort -u)
theirs=$(comm -23 <(printf '%s\n' "$union") <(printf '%s\n' "$mine"))

to_json_array() {
  if [ -z "$1" ]; then echo '[]'; else printf '%s\n' "$1" | jq -R . | jq -s .; fi
}

mkdir -p .claude
jq -n --argjson allow "$(to_json_array "$mine")" --argjson deny "$(to_json_array "$theirs")" \
  '{permissions: {allow: $allow, deny: $deny}}' > .claude/settings.local.json

grep -qxF '.claude/settings.local.json' .git/info/exclude 2>/dev/null \
  || echo '.claude/settings.local.json' >> .git/info/exclude
