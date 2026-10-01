#!/usr/bin/env bash
# Sourced (after runner/flow-lib.sh and runner/trigger-lib.sh). trigger_manual_for <owner/repo> <wf>
# — true if the repo's triggers/ holds a valid `manual` trigger targeting workflow:<wf>.

trigger_manual_for() {
  local repo="$1" wf="$2" names n b64 t kind target err k v
  names="$(gh api "repos/$repo/contents/triggers" --jq '.[].name' 2>/dev/null)" || return 1
  t="$(mktemp)"
  while IFS= read -r n; do
    [[ "$n" == *.md ]] || continue
    b64="$(gh api "repos/$repo/contents/triggers/$n" --jq '.content' 2>/dev/null)" || continue
    base64 -d <<<"$b64" > "$t" 2>/dev/null || continue
    kind=""; target=""; err=""
    while IFS='=' read -r k v; do
      case "$k" in kind) kind="$v" ;; target) target="$v" ;; error) err="$v" ;; esac
    done < <(trigger_read "$t" "${n%.md}")
    if [ "$kind" = manual ] && [ "$target" = "workflow:$wf" ] && [ -z "$err" ]; then rm -f "$t"; return 0; fi
  done <<<"$names"
  rm -f "$t"
  return 1
}
