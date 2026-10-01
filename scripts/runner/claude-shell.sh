#!/usr/bin/env bash
# Let an agent's Bash tool run `claude -p` (hq#261).
# Claude Code strips CLAUDE_CODE_OAUTH_TOKEN from its Bash subprocesses in Actions,
# so the workflow passes the token as HQ_CLAUDE_OAUTH_TOKEN (not stripped) and this
# puts a `claude` function at the top of ~/.bashrc that maps it back for that call.
# Only the variable names appear here, never a value. Safe to re-run.
set -euo pipefail

rc="$HOME/.bashrc"
marker="# hq-claude-shell (hq#261)"
touch "$rc"
grep -qF "$marker" "$rc" && exit 0

block="$marker
claude() { CLAUDE_CODE_OAUTH_TOKEN=\"\${HQ_CLAUDE_OAUTH_TOKEN:-\${CLAUDE_CODE_OAUTH_TOKEN:-}}\" command claude \"\$@\"; }
# end hq-claude-shell
"
tmp="$(mktemp)"
{ printf '%s' "$block"; cat "$rc"; } > "$tmp"
cat "$tmp" > "$rc"
rm -f "$tmp"
