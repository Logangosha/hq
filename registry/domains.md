# Domain Registry

A **domain** is a repo where a certain kind of work and files belong.
HQ uses this list to decide where each Work Item goes.

To add a domain, use `/add-domain`. Only send work to domains with status `active`.

This file is public (HQ is public). Keep repo names and descriptions generic — the
content lives in the private domain repos.

## Owner

Not stored. Every domain repo lives under the same GitHub account as this copy of HQ —
find it with `gh repo view --json owner --jq .owner.login`. That way a fresh copy of HQ is
already correct for whoever made it.

## Domains

| Domain | Repo | Status | What belongs here |
|---|---|---|---|
| hq-test-sandbox | `hq-test-sandbox` | active | Starter domain every copy of HQ gets. Fake content for trying out the system. Safe to break. |

## Status meanings

- **planned**: an idea only. The repo doesn't exist yet.
- **active**: the repo exists and can receive Work Items.
- **retired**: don't send new work here.

## How to reach a domain

Always work with domain repos through GitHub (for example, with the `gh` CLI).
Don't rely on local folders — they differ on every computer.
