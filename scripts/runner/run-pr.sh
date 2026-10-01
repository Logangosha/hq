#!/usr/bin/env bash
# Turns a manually-dispatched agent's file changes into one PR, linked to its run
# Issue. If the agent changed nothing, no branch or commit is made — nor if the
# agent's `tools:` line marks it read-only (hq#196 R16): a read-only agent that
# still wrote something (e.g. via Bash) doesn't get a PR out of it.
# Usage: NUM=29 AGENT=builder GITHUB_REPOSITORY=owner/repo bash .hq/scripts/runner/run-pr.sh
# A plain run also gets a comment on its Issue naming the PR.
# Needs GH_TOKEN. Run from the domain checkout, after HQ was cloned into .hq and
# install-agents.sh has installed HQ's agents/hooks.
# The push authenticates with GH_TOKEN only, ignoring the origin URL and any git
# credentials an earlier step (e.g. claude-code-action) left behind.
# The PR itself opens as the Claude app, not github-actions (which GitHub blocks
# from creating PRs by default): needs id-token: write, which the caller grants.
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

if bash "$(dirname "${BASH_SOURCE[0]}")/agent-tools.sh" ".claude/agents/$AGENT.md" --read-only; then
  echo "Read-only agent $AGENT: not turning these changes into a PR:"
  printf '%s\n' "${CHANGED[@]}"
  exit 0
fi

OIDC=$(curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=claude-code-github-action" | jq -r .value)
[ -n "$OIDC" ] && [ "$OIDC" != "null" ] || { echo "Failed to get an OIDC token" >&2; exit 1; }

APP_TOKEN=$(curl -fsS -X POST -H "Authorization: Bearer $OIDC" \
  https://api.anthropic.com/api/github/github-app-token-exchange | jq -r '.token // .app_token // empty')
[ -n "$APP_TOKEN" ] || { echo "Failed to exchange for a Claude app token" >&2; exit 1; }
echo "::add-mask::$APP_TOKEN"

trap 'curl -fsS -X DELETE -H "Authorization: Bearer $APP_TOKEN" https://api.github.com/installation/token >/dev/null || true' EXIT

BRANCH="run/$NUM-$AGENT"
BODY="Closes #$NUM"
FLOW=
# A workflow item's PR must not close it mid-flow, and repeat runs (a rejection loop)
# must not collide on the branch name.
if [ -f "${RUNNER_TEMP:-/tmp}/hq-flow-step" ]; then
  BRANCH="run/$NUM-$AGENT-${GITHUB_RUN_ID:-$(date +%s)}"
  BODY="Refs #$NUM"
  FLOW=1
fi
# A reply turn runs on the run's existing branch (run-reply.sh put it there).
if [ "$(git rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]; then
  git switch -c "$BRANCH"
fi
git add -A -- "${CHANGED[@]}"
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -m "Run #$NUM: $AGENT"
git -c http.https://github.com/.extraheader= \
  -c credential.helper= \
  -c credential.helper='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f' \
  push "https://github.com/$GITHUB_REPOSITORY.git" "HEAD:refs/heads/$BRANCH"

# An earlier turn already opened the PR: the push updated it.
if [ -z "$FLOW" ]; then
  OPEN_PR="$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$BRANCH" --state open --json url --jq '.[0].url // empty')"
  if [ -n "$OPEN_PR" ]; then
    echo "$OPEN_PR"
    gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" \
      --body "Updated PR #${OPEN_PR##*/} with these changes: $OPEN_PR"
    exit 0
  fi
fi

PR_URL=$(GH_TOKEN="$APP_TOKEN" gh pr create --repo "$GITHUB_REPOSITORY" --head "$BRANCH" \
  --title "Run #$NUM: $AGENT" \
  --body "$BODY")
echo "$PR_URL"

# Name the PR on the run Issue so its result says where the changes went.
if [ -z "$FLOW" ]; then
  gh issue comment "$NUM" --repo "$GITHUB_REPOSITORY" \
    --body "Opened PR #${PR_URL##*/} with these changes: $PR_URL"
fi
