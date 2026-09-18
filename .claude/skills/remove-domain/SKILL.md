---
name: remove-domain
description: Unregister a domain repo so HQ no longer sees it or sends Work Items there — the repo, its files and Issues are left as they are. Use when the user says "remove a domain", "unregister <repo>", "stop using HQ in <repo>", or "/remove-domain".
---

# Remove a domain

HQ keeps no list, so a repo is a domain only because it has the Work Item workflow. To
unregister it, take that off the repo. Nothing else changes — files, Issues, labels and the
token stay, so `/add-domain <repo>` brings it straight back.

## 1. Which repo

- **Owner:** `gh repo view --json owner --jq .owner.login`
- **Repo:** from the user. It must show up in `bash scripts/list-domains.sh`. If it doesn't,
  tell them in one line that it isn't a domain, and stop.

## 2. Open Work Items *(warn, don't block)*

```bash
gh issue list --repo <owner>/<repo> --state open --limit 200 --json number,title,labels \
  --jq '.[] | select(any(.labels[]; .name | startswith("stage:"))) | "#\(.number) \(.title)"'
```

If there are any, list them and say the agents will stop running on them. Ask once whether
to go ahead.

## 3. Unregister

```bash
SHA=$(gh api repos/<owner>/<repo>/contents/.github/workflows/work-item.yml --jq .sha)
gh api -X DELETE repos/<owner>/<repo>/contents/.github/workflows/work-item.yml \
  -f message="Unregister from HQ" -f sha="$SHA"
gh repo edit <owner>/<repo> --remove-topic hq-domain
```

## 4. Confirm

Run `bash scripts/list-domains.sh`. The repo must be gone. Then one line: it's
unregistered, and `/add-domain <repo>` re-adds it.
