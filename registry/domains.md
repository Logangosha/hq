# Domain Registry

A **domain** is a repo where a certain kind of work and files belong.
HQ uses this list to decide where each Work Item goes.

To add a domain, add a row. Only send work to domains with status `active`.

## Settings

- **GitHub owner:** `Logangosha`

## Domains

| Domain | Repo | Status | What belongs here |
|---|---|---|---|
| hq-test-sandbox | `hq-test-sandbox` | active | Fake test content for trying out the system. Safe to break. |

## Status meanings

- **planned**: an idea only. The repo doesn't exist yet.
- **active**: the repo exists and can receive Work Items.
- **retired**: don't send new work here.

## How to reach a domain

Always work with domain repos through GitHub (for example, with the `gh` CLI).
Don't rely on local folders — they differ on every computer.
