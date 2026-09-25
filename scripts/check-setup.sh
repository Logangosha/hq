#!/usr/bin/env bash
# Report what's set up and what's missing. Changes nothing.
# Usage: bash scripts/check-setup.sh
#
# The owner is whoever owns this copy of HQ. Domains are that owner's repos with the
# Work Item workflow installed (scripts/list-domains.sh).
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
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

[ -z "$HQ_REPO" ] && { echo; exit 1; }
OWNER="${HQ_REPO%%/*}"
ME="$(gh api user --jq .login)"
[ "$OWNER" = "$ME" ] && ok "owner: $OWNER" \
  || bad "this HQ belongs to $OWNER, but gh is logged in as $ME" "copy HQ into your own account (README → How to use)"

DOMAINS_RAW="$(bash "$HERE/scripts/list-domains.sh")"
if [ "${DOMAINS_RAW%%$'\t'*}" = "REFUSAL" ]; then
  KIND="$(printf '%s' "$DOMAINS_RAW" | cut -f2)"
  bad "GitHub refused the request ($KIND)" "check your token, rate limit, or network, then run this again"
  echo; exit 1
fi
DOMAINS="$(printf '%s\n' "$DOMAINS_RAW" | cut -f1)"
if [ -z "$DOMAINS" ]; then
  bad "no domains yet (no repo of yours has the Work Item workflow)" "/add-domain <repo>"
fi

for D in $DOMAINS; do
  R="$OWNER/$D"
  echo; echo "Domain: $R"
  gh api "repos/$R/contents/.github/workflows/work-item.yml" --silent 2>/dev/null \
    && ok "workflow installed" || bad "workflow file missing" "/add-domain $D"
  gh label list --repo "$R" --search stage:requirements --json name --jq '.[].name' | grep -qx stage:requirements \
    && ok "labels" || bad "labels missing" "/add-domain $D"
  gh secret list --repo "$R" 2>/dev/null | grep -q CLAUDE_CODE_OAUTH_TOKEN \
    && ok "CLAUDE_CODE_OAUTH_TOKEN secret" \
    || bad "no Claude token secret" "copy the token from 'claude setup-token', then in PowerShell:
       gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo $R --body ((Get-Clipboard -Raw) -replace '\\s','')"
  gh secret list --repo "$R" 2>/dev/null | grep -q HQ_RELEASE_TOKEN \
    && ok "HQ_RELEASE_TOKEN secret" \
    || bad "no release token secret" "setup-hq step 4.4"
done

echo
echo "Can't check from here: the Claude GitHub App. Open https://github.com/settings/installations"
echo "— Claude must be listed, with access to All repositories."
echo
[ "$PROBLEMS" -eq 0 ] && echo "All set." || echo "$PROBLEMS thing(s) to fix."
