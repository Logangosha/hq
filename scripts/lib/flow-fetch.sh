#!/usr/bin/env bash
# Sourced. flow_fetch <owner/repo> <name> <outfile> — copy the workflow file
# workflows/<name>.md to <outfile>: the domain's own, else HQ's (this checkout).
# Prints `repo` or `hq`; returns 1 if neither has it.

flow_fetch() {
  local repo="$1" name="$2" out="$3" b64 hq
  [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
  if b64="$(gh api "repos/$repo/contents/workflows/$name.md" --jq '.content' 2>/dev/null)" \
    && base64 -d <<<"$b64" > "$out" 2>/dev/null && [ -s "$out" ]; then
    echo repo
    return 0
  fi
  hq="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/workflows/$name.md"
  if [ -f "$hq" ]; then
    cp "$hq" "$out"
    echo hq
    return 0
  fi
  return 1
}
