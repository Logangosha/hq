#!/usr/bin/env bash
# Report what's set up and what's missing. Changes nothing.
# Usage: bash scripts/check-setup.sh
#
# Reads the owner and the active domains from registry/domains.md.
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REG="$HERE/registry/domains.md"
PROBLEMS=0

ok()   { echo "  ✅ $1"; }
bad()  { echo "  ❌ $1"; echo "     → $2"; PROBLEMS=$((PROBLEMS + 1)); }

echo "Tools"
command -v git >/dev/null && ok "git" || bad "git not installed" "https://git-scm.com/downloads"
if ! command -v gh >/dev/null; then
  bad "GitHub CLI not installed" "https://cli.github.com, then: gh auth login"
  echo; echo "Fix the above and run this again."; exit 1
fi
ok "GitHub CLI"
if gh auth status >/dev/null 2>&1; then ok "gh logged in as $(gh api user --jq .login)"
else bad "gh not logged in" "gh auth login"; echo; exit 1; fi

echo; echo "HQ"
HQ_REPO="$(cd "$HERE" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"
if [ -z "$HQ_REPO" ]; then
  bad "this folder isn't linked to a GitHub repo" "push HQ to GitHub first"
else
  VIS="$(gh repo view "$HQ_REPO" --json visibility --jq .visibility)"
  [ "$VIS" = PUBLIC ] && ok "$HQ_REPO is public" \
    || bad "$HQ_REPO is $VIS" "domain repos fetch the agents from it, so it must be public"
fi

OWNER="$(sed -nE 's/.*\*\*GitHub owner:\*\* `([^`]+)`.*/\1/p' "$REG")"
if [ -z "$OWNER" ] || [ "$OWNER" = "your-github-name" ]; then
  bad "no GitHub owner in registry/domains.md" "run /setup-hq"
  echo; exit 1
fi
ok "owner: $OWNER"

# Rows look like: | name | `repo` | active | ... |
DOMAINS="$(sed -nE 's/^\|[^|]+\| *`([^`]+)` *\| *active *\|.*/\1/p' "$REG")"
if [ -z "$DOMAINS" ]; then
  bad "no active domains in registry/domains.md" "run /setup-hq"
fi

for D in $DOMAINS; do
  R="$OWNER/$D"
  echo; echo "Domain: $R"
  if ! gh repo view "$R" >/dev/null 2>&1; then
    bad "repo doesn't exist" "run /setup-hq, or: gh repo create $R --private"
    continue
  fi
  ok "repo exists"
  gh api "repos/$R/contents/.github/workflows/work-item.yml" >/dev/null 2>&1 \
    && ok "workflow installed" || bad "no workflow" "bash scripts/enable-agents.sh $R"
  gh label list --repo "$R" --search stage:requirements --json name --jq '.[].name' | grep -qx stage:requirements \
    && ok "labels" || bad "labels missing" "bash scripts/create-labels.sh $R"
  gh secret list --repo "$R" 2>/dev/null | grep -q CLAUDE_CODE_OAUTH_TOKEN \
    && ok "CLAUDE_CODE_OAUTH_TOKEN secret" \
    || bad "no Claude token secret" "copy the token from 'claude setup-token', then in PowerShell:
       gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $R --body ((Get-Clipboard -Raw) -replace '\\s','')"
done

echo
echo "Can't check from here: the Claude GitHub App. Open https://github.com/settings/installations"
echo "— Claude must be listed, with access to All repositories."
echo
[ "$PROBLEMS" -eq 0 ] && echo "All set." || echo "$PROBLEMS thing(s) to fix."
