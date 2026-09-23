#!/usr/bin/env bash
# The Issue, cut down to what a stage agent needs: the goal, then the latest comment
# from each stage, every human comment, and nothing from the metrics runs.
# Usage: bash .hq/scripts/runner/issue-digest.sh <owner/repo> <issue-number>
# Prints the digest to stdout. The full history is still `gh issue view <n> --comments`.
#
# Kept/dropped (hq#79 R3-R7):
#   dropped  after-run.sh metrics comments — a bot comment with an `<!-- hq-run` marker
#            line. Anchored to the start of a line: a stage comment that *quotes* the
#            marker in its text (hq#78's V7 does) is a real comment and stays.
#   dropped  an agent stage comment with a later comment for the same stage number
#            (`## 3.`, `## 3b.`, `## 3c.` are all stage 3 — the last one wins)
#   kept     every human comment, in full, whatever it says
#   kept     every other bot comment (three-strikes, a failed agent step)
set -euo pipefail

REPO="${1:-}"
NUM="${2:-}"
if [ -z "$REPO" ] || [ -z "$NUM" ]; then
  echo "usage: issue-digest.sh <owner/repo> <issue-number>" >&2
  exit 2
fi

# The goal, verbatim and first. Nothing prints above it (R2).
gh api "repos/$REPO/issues/$NUM" --jq '.body'

COMMENTS="$(gh api --paginate "repos/$REPO/issues/$NUM/comments" \
  --jq '.[] | {login: .user.login, type: .user.type, created_at: .created_at, body: .body}' \
  | jq -s '.')"

FILTER='
  map(select(
      (.type == "User")
      or (((.body // "") | split("\n") | any(startswith("<!-- hq-run"))) | not)
    ))
  | [ to_entries[] | .value + {idx: .key} ]
  | map(. + {
      human: (.type == "User"),
      stage: ((((.body // "") | split("\n")[0]) | capture("^## *(?<d>[0-9]+)[A-Za-z]*\\.") | .d) // null)
    })
  | ( map(select((.human | not) and .stage != null))
      | group_by(.stage)
      | map({key: .[0].stage, value: (map(.idx) | max)})
      | from_entries ) as $last
  | map(select(.human or (.stage == null) or ($last[.stage] == .idx)))
'

KEPT="$(jq "$FILTER" <<<"$COMMENTS")"

jq -r '.[] | "\n--- \(.login) · \(.created_at) ---\n\(.body)"' <<<"$KEPT"

printf '\n--- digest: %s of %s comments ---\n' \
  "$(jq 'length' <<<"$KEPT")" "$(jq 'length' <<<"$COMMENTS")"
