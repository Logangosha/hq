#!/usr/bin/env bash
# Add starter files to a domain repo: README.md, CLAUDE.md, and a note in each of
# .claude/agents/, .claude/skills/ and workflows/.
# Usage: bash scripts/add-starter-files.sh owner/repo
#
# Only missing files are added. Nothing already there is overwritten. Safe to re-run.
set -euo pipefail

REPO="${1:-}"
if [ -z "$REPO" ]; then
  echo "Usage: bash scripts/add-starter-files.sh owner/repo" >&2
  exit 1
fi

shopt -u patsub_replacement 2>/dev/null || true

NAME="${REPO#*/}"
DESC="$(gh repo view "$REPO" --json description --jq .description)"
if [ -z "$DESC" ]; then
  echo "Repo $REPO has no description — set one first." >&2
  exit 1
fi
HQ_REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMPL_DIR="$HERE/orchestration/domain-starter"

# tmpl file | path in target repo
FILES=(
  "README.md.tmpl|README.md"
  "CLAUDE.md.tmpl|CLAUDE.md"
  "agents.md.tmpl|.claude/agents/README.md"
  "skills.md.tmpl|.claude/skills/README.md"
  "workflows.md.tmpl|workflows/README.md"
)

for ENTRY in "${FILES[@]}"; do
  TMPL="${ENTRY%%|*}"
  TARGET="${ENTRY##*|}"

  if gh api "repos/$REPO/contents/$TARGET" >/dev/null 2>&1; then
    echo "kept $TARGET"
    continue
  fi

  TEXT="$(cat "$TMPL_DIR/$TMPL")"
  TEXT="${TEXT//__NAME__/$NAME}"
  TEXT="${TEXT//__DESCRIPTION__/$DESC}"
  TEXT="${TEXT//__HQ_REPO__/$HQ_REPO}"

  CONTENT="$(printf '%s' "$TEXT" | base64 | tr -d '\n')"

  gh api "repos/$REPO/contents/$TARGET" -X PUT \
    -f message="Add starter file $TARGET" \
    -f content="$CONTENT" >/dev/null

  echo "added $TARGET"
done
