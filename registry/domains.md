# Domains

A **domain** is a repo where a certain kind of work and files belong. HQ sends each Work
Item to one.

## Nothing is listed here, on purpose

HQ is public, so any list in this file would show your repos to anyone. Instead:

| What | Where it comes from |
|---|---|
| **Owner** | Whoever owns this copy of HQ |
| **Which repos are domains** | The owner's repos that have the Work Item workflow installed |
| **What belongs in each** | That repo's GitHub description |

See them with `bash scripts/list-domains.sh`. Every copy of HQ finds only its own owner's
repos, so a fresh copy starts empty.

## Adding and removing

- **Add:** `/add-domain <repo>` — installs the workflow and sets the description.
- **Retire:** delete `.github/workflows/work-item.yml` from that repo. HQ stops seeing it.

## How to reach a domain

Always through GitHub (`gh`). Don't rely on local folders — they differ on every computer.
