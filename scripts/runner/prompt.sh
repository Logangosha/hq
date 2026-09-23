#!/usr/bin/env bash
# What the stage agent is told when it starts. Kept here, not in the workflow, so the
# agents can change their own briefing (a file under .github/workflows/ is one they are
# never allowed to push).
# Usage: NUM=29 NAME=builder LABEL=stage:build REPO=owner/repo bash .hq/scripts/runner/prompt.sh
# Writes text=<the prompt> to $GITHUB_OUTPUT (stdout when that isn't set).
set -euo pipefail

: "${NUM:?}" "${NAME:?}" "${LABEL:?}" "${REPO:?}"

read -r -d '' PROMPT <<EOF || true
Work Item #$NUM in $REPO has just been labelled \`$LABEL\`, so you are the
**$NAME** agent for it.

1. Read \`.hq/orchestration/lifecycle.md\` — the rules of the system.
2. Read \`.claude/agents/$NAME.md\` and do exactly what it says for this
   Issue. It is your whole job description.
3. Read the Issue first — the goal, the latest comment from each stage, and every
   human comment:
   \`bash .hq/scripts/runner/issue-digest.sh $REPO $NUM\`
   Superseded stage comments are left out. If the digest points at an earlier run
   you need to see, \`gh issue view $NUM --comments\` has the full history.

Finish by posting your stage comment and setting the \`stage:\` label to the
next stage (or back, if you are bouncing it). Use \`gh\` for both. Nothing
else happens until that label changes.
EOF

OUT="${GITHUB_OUTPUT:-/dev/stdout}"
DELIM="prompt-$(date +%s%N)"
printf 'text<<%s\n%s\n%s\n' "$DELIM" "$PROMPT" "$DELIM" >> "$OUT"
