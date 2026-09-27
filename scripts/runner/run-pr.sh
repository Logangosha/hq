#!/usr/bin/env bash
# Turns a manually-dispatched agent's file changes into one PR, linked to its run
# Issue. If the agent changed nothing, no branch or commit is made.
# Usage: NUM=29 AGENT=builder GITHUB_REPOSITORY=owner/repo bash .hq/scripts/runner/run-pr.sh
# Needs GH_TOKEN. Run from the domain checkout, after HQ was cloned into .hq and
# install-agents.sh has installed HQ's agents/hooks.
set -euo pipefail

: "${NUM:?}" "${AGENT:?}" "${GITHUB_REPOSITORY:?}"

# Paths the installers copy in (install-agents.sh, install-hooks.sh). An untracked
# file identical to the copy it came from isn't a change the agent made.
declare -A INSTALLED=(
  [".claude/hooks/trim-output.sh"]=".hq/.claude/hooks/trim-output.sh"
  [".claude/settings.local.json"]=".hq/orchestration/agent-hooks.json"
)

CHANGED=()
while IFS= read -r -d '' ENTRY; do
  STATUS="${ENTRY:0:2}"
  PATH_PART="${ENTRY:3}"

  [[ "$PATH_PART" == .hq/* ]] && continue

  if [ "$STATUS" = "??" ]; then
    ORIGIN="${INSTALLED[$PATH_PART]:-}"
    if [ -z "$ORIGIN" ] && [[ "$PATH_PART" == .claude/agents/*.md ]]; then
      ORIGIN=".hq/.claude/agents/$(basename "$PATH_PART")"
    fi
    if [ -n "$ORIGIN" ] && cmp -s "$PATH_PART" "$ORIGIN" 2>/dev/null; then
      continue
    fi
  fi

  CHANGED+=("$PATH_PART")
done < <(git status --porcelain -z --untracked-files=all)

if [ "${#CHANGED[@]}" -eq 0 ]; then
  echo "No file changes"
  exit 0
fi

BRANCH="run/$NUM-$AGENT"
git switch -c "$BRANCH"
git add -A -- "${CHANGED[@]}"
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Run #$NUM: $AGENT"
git push origin HEAD

gh pr create --repo "$GITHUB_REPOSITORY" --head "$BRANCH" \
  --title "Run #$NUM: $AGENT" \
  --body "Closes #$NUM"
