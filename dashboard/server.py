"""HQ review dashboard: a local page listing every open Work Item, with the ones that
need you on top (F8.4). Review opens one: its branch is checked out on this computer
and its code changes shown, with Start/Stop/Restart/Open for its app if it has one
(F8.5); then you approve or reject it with a comment (F8.6). Runs here, not on GitHub,
so the buttons can use HQ's scripts and your local copies of the repos.

Usage: python dashboard/server.py        then open http://localhost:8765
"""
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import ctl
import ghcache

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(HQ, "dashboard", "index.html")
PORT = int(os.environ.get("PORT", "8765"))
# Backstop only (R8): long enough that a 60s ping from an open tab never trips it.
APP_IDLE_TIMEOUT = 300
# Read once: reviewing HQ itself checks out other branches under this server.
with open(PAGE, encoding="utf-8") as fh:
    PAGE_HTML = fh.read()

STAGE_NAMES = {
    "stage:scope": "1 Scope",
    "stage:requirements": "1 Requirements",
    "stage:verification": "2 Verification",
    "stage:plan": "3 Plan",
    "stage:build": "4 Build",
    "stage:qa": "5 QA",
    "stage:review": "6 Human review",
}

# The progress bar's 7 segments, in lifecycle order (F8.7). Done has no label — the
# dashboard only lists open Issues, so it's always "ahead"/"not started". Scope is a
# small-item-only stage, so it's excluded here (SMALL_ORDER below covers it).
STAGE_ORDER = [(l, n) for l, n in STAGE_NAMES.items() if l != "stage:scope"] + [(None, "Done")]

# The small path's 3-segment progress bar (R13): Scope, Build, Review, no Done segment.
SMALL_ORDER = [("stage:scope", "Scope"), ("stage:build", "Build"), ("stage:review", "Review")]


def find_bash():
    # On Windows, plain "bash" can be WSL's, which has no gh login. Use Git's.
    git = shutil.which("git")
    if os.name == "nt" and git:
        root = os.path.dirname(os.path.dirname(git))  # ...\Git\cmd\git.exe -> ...\Git
        candidate = os.path.join(root, "bin", "bash.exe")
        if os.path.exists(candidate):
            return candidate
    return shutil.which("bash") or "bash"


BASH = find_bash()
# "<repo>#<n>" -> {"default", "path", "pr", "app", "port", "url", "heartbeat", "watchdog"}
# app/port/url/heartbeat/watchdog are None until Start.
reviews = {}
known = set()  # owner/repo of every domain, from the last listing


# The server runs detached, so it has no console of its own: without this, Windows gives
# every child console app (gh, git, bash) a brand-new window, which flashes on every poll.
NO_WINDOW = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}


def run(args, cwd=HQ, check=True):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                          encoding="utf-8", check=check, **NO_WINDOW)


def hq_version():
    """Commit currently being served, and how far behind its tracked remote — computed
    once at import, like PAGE_HTML: a running server's page stays frozen to what was
    launched even if the checkout changes later (e.g. during self-review)."""
    sha = run(["git", "rev-parse", "--short", "HEAD"], check=False).stdout.strip()
    behind = run(["git", "rev-list", "--count", "HEAD..@{u}"], check=False).stdout.strip()
    return f"{sha} ({behind} behind)" if behind.isdigit() and int(behind) > 0 else sha


PAGE_HTML = PAGE_HTML.replace("{{HQ_VERSION}}", hq_version())


REFUSAL_MESSAGES = {
    "rate_limit": "GitHub's rate limit was hit.",
    "auth": "GitHub's token is invalid or expired.",
    "offline": "Can't reach GitHub — check your network.",
}


class RefusalError(Exception):
    """gh refused a request: rate limit, bad/expired token, or no network."""
    def __init__(self, kind, message):
        super().__init__(message)
        self.kind = kind
        self.message = message


def _refusal(kind, detail=""):
    message = REFUSAL_MESSAGES.get(kind, "GitHub refused the request.")
    if kind == "rate_limit" and detail:
        try:
            reset = datetime.fromtimestamp(int(detail)).strftime("%I:%M %p").lstrip("0")
            message += f" Try again after {reset}."
        except ValueError:
            pass
    elif kind == "auth":
        message += " Run `gh auth login` with a fresh token."
    return RefusalError(kind, message)


_owner = None


def owner():
    """OWNER, fetched once and cached. A refusal here (bad token, offline) surfaces through
    work_items() like one from ghcache, instead of crashing the server at import time."""
    global _owner
    if _owner is None:
        res = run(["gh", "repo", "view", "--json", "owner", "--jq", ".owner.login"], check=False)
        if res.returncode != 0:
            raise _refusal(*ghcache.classify(res.stderr))
        _owner = res.stdout.strip()
    return _owner


# Stage display name (from STAGE_NAMES above) -> its stage: label / agent name (from
# scripts/runner/which-agent.sh). Stage 6 (human review) is deliberately absent: it's the
# user's turn, so a finished run there is normal, not a stall.
STAGE_LABEL = {
    "1 Scope": "stage:scope",
    "1 Requirements": "stage:requirements", "2 Verification": "stage:verification",
    "3 Plan": "stage:plan", "4 Build": "stage:build", "5 QA": "stage:qa",
}
STAGE_AGENT = {
    "1 Scope": "scope",
    "1 Requirements": "requirements", "2 Verification": "verification",
    "3 Plan": "planner", "4 Build": "builder", "5 QA": "qa",
}
AGENT_LABEL = {
    "scope": "Scope",
    "requirements": "Requirements", "verification": "Verification",
    "planner": "Planner", "builder": "Builder", "qa": "QA",
}
# Stages restart() may target — the same five agent stages, so the two lists can't drift.
RESTART_STAGES = {l.split(":", 1)[1] for l in STAGE_LABEL.values()}


def stage_label_time(full, number, label, created_at):
    """When `label` most recently landed on the issue, or its creation time if it was
    only ever set there (no later "labeled" event, e.g. a label set at creation)."""
    events = json.loads(run(["gh", "api", f"repos/{full}/issues/{number}/events", "--paginate",
                             "--jq", f'[.[] | select(.event=="labeled" and .label.name=="{label}") '
                                     '| .created_at]'], check=False).stdout or "[]")
    return events[-1] if events else created_at


def stall_info(full, item, comments):
    """Whether this Work Item's current stage looks stuck: 15+ minutes have passed since
    the stage label landed on the Issue (F7.10) — the only test, regardless of comments
    or Actions run history. Posts the first comment for a stall and stays quiet after
    that; parks the item on a 3rd stall in a row on the same stage, with no successful
    stage comment in between.

    Returns (stalled, reason, just_parked) — just_parked is True only on the call that
    adds waiting:user, so work_items() can reflect it in this same response's `waiting`
    list instead of waiting for a second poll."""
    stage, number = item["stage"], item["number"]
    since = stage_label_time(full, number, STAGE_LABEL[stage], item["created_at"])
    elapsed = datetime.utcnow() - datetime.strptime(since, "%Y-%m-%dT%H:%M:%SZ")
    if elapsed < timedelta(seconds=900):
        return False, None, False  # stage started under 15 min ago — give it time

    title = stage.split(" ", 1)[1]
    reason = (f"🛑 Stalled: **{title}** — 15+ minutes have passed since this stage started "
              "with no new comment or label change. A person needs to look, or Restart.")
    after = [c for c in comments if c["created_at"] >= since]
    if after and after[-1]["body"] == reason:
        return True, reason, False  # already recorded this stall episode

    run(["gh", "issue", "comment", str(number), "--repo", full, "--body", reason])

    agent = STAGE_AGENT[stage]
    heading = [i for i, c in enumerate(comments)
               if c["body"].startswith("## ") and f"— {agent}" in c["body"]]
    tail = comments[heading[-1] + 1:] if heading else comments
    strikes = 1 + sum(1 for c in tail if c["body"].startswith(f"🛑 Stalled: **{title}**"))
    parked = strikes >= 3
    if parked:
        run(["gh", "issue", "edit", str(number), "--repo", full,
             "--add-label", "waiting:user", "--add-assignee", full.split("/")[0]])
    return True, reason, parked


BLOCKER_RE = re.compile(r"Blocked by ((?:`[^`]+`(?:, )?)+)")
BLOCKER_REF_RE = re.compile(r"`([^`]+)`")
DROP_RE = re.compile(r"^🛑 Blocker `([^`]+)`")
ANSWER_RE = re.compile(r"^## Answer — user")


def parse_blockers(comments):
    """Every `owner/repo#N` a blocked Work Item names in its creation comment (the
    first comment that matches), in order. Reads both the old one-blocker comment
    and the new several-blocker one — same regex, one or many refs in the group."""
    for c in comments:
        m = BLOCKER_RE.search(c["body"])
        if m:
            return BLOCKER_REF_RE.findall(m.group(1))
    return []


def blocker_state(ref):
    """'open', 'merged' (CLOSED+COMPLETED) or 'closed without merging' for `ref`.
    A blocker we can't read counts as open — the item stays parked, don't guess."""
    bfull, bnum = ref.rsplit("#", 1)
    res = run(["gh", "issue", "view", bnum, "--repo", bfull, "--json", "state,stateReason"],
              check=False)
    if res.returncode != 0:
        return "open"
    info = json.loads(res.stdout)
    if info["state"] != "CLOSED":
        return "open"
    return "merged" if info["stateReason"] == "COMPLETED" else "closed without merging"


def dropped_settled(ref, comments):
    """True if a 🛑 drop comment for `ref` has a later Answer comment (R6): the user
    has already dealt with this one dropped blocker, so it shouldn't hold the item
    forever once the rest merge."""
    drop_at = None
    for c in comments:
        if DROP_RE.match(c["body"]) and DROP_RE.match(c["body"]).group(1) == ref:
            drop_at = c.get("created_at") or c.get("createdAt")
    if drop_at is None:
        return False
    return any(ANSWER_RE.match(c["body"])
               and (c.get("created_at") or c.get("createdAt")) > drop_at
               for c in comments)


def reconcile_blockers(full, it, comments):
    """Release a blocked Work Item once every blocker closes (R4-R6): merged (or a
    dropped-and-answered blocker) starts Requirements; a newly closed-without-merging
    blocker surfaces the drop for the user instead of releasing on its own. Runs from
    the same poll as stall_info, so a PR merged straight on GitHub is picked up too,
    not only one merged through the dashboard."""
    refs = parse_blockers(comments)
    it["blocked_by"] = [{"ref": r, "state": blocker_state(r)} for r in refs]
    if not refs or "waiting:user" in it["waiting"]:
        return  # nothing recorded, or already surfaced and parked for the user
    number = str(it["number"])
    dropped = [b["ref"] for b in it["blocked_by"] if b["state"] == "closed without merging"]
    new_drops = [r for r in dropped
                 if not any(DROP_RE.match(c["body"]) and DROP_RE.match(c["body"]).group(1) == r
                            for c in comments)]
    if new_drops:
        ref = new_drops[0]  # one 🛑 per ref, ever — surface one at a time
        run(["gh", "issue", "comment", number, "--repo", full,
             "--body", f"🛑 Blocker `{ref}` was closed without merging. A person needs to "
                       "decide: release this Work Item (Answer) or drop it too."])
        run(["gh", "issue", "edit", number, "--repo", full, "--add-label", "waiting:user"])
        it["waiting"].append("waiting:user")
        it["needs_you"] = True
        return
    settled = all(b["state"] == "merged" or
                  (b["state"] == "closed without merging" and dropped_settled(b["ref"], comments))
                  for b in it["blocked_by"])
    if not settled:
        return
    small = it.get("size") == "small"
    next_stage = "stage:scope" if small else "stage:requirements"
    next_name = "Scope" if small else "Requirements"
    if len(refs) == 1:
        text = f"Blocker `{refs[0]}` merged. Starting {next_name}."
    else:
        joined = ", ".join(f"`{r}`" for r in refs)
        text = f"Blockers {joined} done. Starting {next_name}."
    run(["gh", "issue", "comment", number, "--repo", full, "--body", text])
    # Two calls, remove then add (same idiom as resume()): the labeled event that
    # starts the next agent must not still show waiting:work, or the runner's
    # waiting: guard skips it.
    run(["gh", "issue", "edit", number, "--repo", full, "--remove-label", "waiting:work"])
    run(["gh", "issue", "edit", number, "--repo", full, "--add-label", next_stage])
    it["stage"], it["waiting"] = ("1 Scope" if small else "1 Requirements"), []


def nest_parts(domains):
    """Move each open part (F9) out of its own domain's `items` into its parent's
    `parts`, in sub-issue order — wherever the part's repo is, so cross-repo parents
    work too (R17). A part is never left both nested and top-level."""
    by_ref = {(d["full"], it["number"]): it for d in domains for it in d["items"]}
    by_full = {d["full"]: d for d in domains}
    remove = {d["full"]: set() for d in domains}
    for d in domains:
        for p in d["parents"]:
            for full, number in p.pop("_refs"):
                it = by_ref.get((full, number))
                if it is None:
                    continue
                it["full"], it["repo"] = full, by_full[full]["repo"] if full in by_full else full.split("/")[-1]
                p["parts"].append(it)
                remove[full].add(number)
    for d in domains:
        if remove[d["full"]]:
            d["items"] = [it for it in d["items"] if it["number"] not in remove[d["full"]]]
        d["items"] = d.pop("parents") + d["items"]
    return domains


def domain_comments(full):
    """Every issue comment in the domain, grouped by issue number. One cached,
    ETag-conditional call (like the rest of work_items()) instead of one per issue."""
    by_number = {}
    for c in ghcache.fetch_all(f"repos/{full}/issues/comments?per_page=100", run):
        number = int(c["issue_url"].rsplit("/", 1)[-1])
        by_number.setdefault(number, []).append(c)
    for comments in by_number.values():
        comments.sort(key=lambda c: c["created_at"])
    return by_number


HQ_RUN_RE = re.compile(r"^<!-- hq-run (\{.*\}) -->$", re.M)


def _hq_runs(comments):
    """Every `<!-- hq-run {...} -->` block among `comments`, tagged with its own
    comment's created_at so a stage with several runs (bounce/re-run) can be aggregated
    and the latest one found (R5). Only a block starting its own line counts, so a quoted
    example inside comment text can't be picked up; if a comment somehow has more than
    one, the last one that parses wins."""
    runs = []
    for c in comments:
        data = None
        for m in HQ_RUN_RE.finditer(c["body"]):
            try:
                data = json.loads(m.group(1))
            except json.JSONDecodeError:
                continue
        if data is None:
            continue
        data["created_at"] = c["created_at"]
        runs.append(data)
    return runs


def _num(v):
    """A run field as a float, or None if it's "unknown" or otherwise unparsable."""
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _cost_summary(runs):
    """R2/R3: "no data" with zero hq-run comments, "unknown" if none report a usable
    cost, else the numeric sum."""
    if not runs:
        return "no data"
    costs = [c for c in (_num(r.get("cost")) for r in runs) if c is not None]
    return sum(costs) if costs else "unknown"


def _stage_breakdown(runs):
    """One row per stage that has at least one hq-run comment (R4), in the order each
    stage first appears (`runs` is already chronological). A stage with more than one
    run (R5) sums turns/tokens/cost across them and takes model from the latest-created_at
    run. Signal only, per the user's stage-6 rejection: agent, model, turns, total tokens
    and cost — no effort, no input/output/cache split."""
    order, by_stage = [], {}
    for r in runs:
        stage = STAGE_NAMES.get(f"stage:{r.get('stage')}", r.get("stage") or "unknown")
        if stage not in by_stage:
            order.append(stage)
            by_stage[stage] = []
        by_stage[stage].append(r)
    rows = []
    for stage in order:
        group = by_stage[stage]
        latest = max(group, key=lambda r: r["created_at"])
        row = {"agent": AGENT_LABEL.get(STAGE_AGENT.get(stage), "unknown"),
               "model": latest.get("model") or "unknown"}
        turns = [v for v in (_num(r.get("turns")) for r in group) if v is not None]
        row["turns"] = sum(turns) if turns else "unknown"
        token_fields = ("input_tokens", "output_tokens", "cache_tokens")
        token_vals = [_num(r.get(f)) for r in group for f in token_fields]
        token_vals = [v for v in token_vals if v is not None]
        row["tokens"] = sum(token_vals) if token_vals else "unknown"
        costs = [v for v in (_num(r.get("cost")) for r in group) if v is not None]
        row["cost"] = sum(costs) if costs else "unknown"
        rows.append(row)
    return rows


def _progress(stage_label, events, runs, now, colors=None, order=None):
    """F8.7: one dict per STAGE_ORDER segment — {name, state, entered, duration, ongoing,
    cost, unknown_runs, color} — built with no `gh` calls so QA can feed it fake events/runs.
    `colors`: {label: hex} for the item's repo, e.g. from `repos/{full}/labels` — Done has
    no label so it always gets color=None (R11).

    entered: a `labeled` event for that stage's label ever landed, or it has a run (R8).
    state (R3/R4): position relative to `stage_label` (current label, or None if the item
    carries no stage: label) — done/current/ahead, or done/ahead by `entered` if None.
    duration (R5): summed wall-clock time across every visit. A visit starts at `labeled`
    and ends at the next `unlabeled` of the same label, the next `labeled` of any stage:*
    label, or `now` (then `ongoing=True`). Stages with no labeled event ever -> duration
    None ("unknown", R7).
    cost/unknown_runs (R6/R7): sum of numeric `cost` over that stage's runs; `unknown_runs`
    counts runs with no numeric cost. No runs at all -> cost None (Human review/Done always
    do, since they have no agent)."""
    order = order or STAGE_ORDER
    order_labels = [label for label, _ in order]
    stage_events = sorted(
        (e for e in events if e.get("event") in ("labeled", "unlabeled")
         and (e.get("label") or {}).get("name") in STAGE_NAMES),
        key=lambda e: e["created_at"])

    durations, ongoing, entered_labels = {}, {}, set()
    open_visit = None  # (label, start_datetime)

    def close(label, start, end):
        durations[label] = durations.get(label, 0.0) + (end - start).total_seconds()

    for e in stage_events:
        label = e["label"]["name"]
        ts = datetime.strptime(e["created_at"], "%Y-%m-%dT%H:%M:%SZ")
        if e["event"] == "labeled":
            entered_labels.add(label)
            if open_visit is not None:
                close(*open_visit, ts)
            open_visit = (label, ts)
        elif open_visit is not None and open_visit[0] == label:
            close(*open_visit, ts)
            open_visit = None
    if open_visit is not None:
        close(*open_visit, now)
        ongoing[open_visit[0]] = True

    runs_by_stage = {}
    for r in runs:
        runs_by_stage.setdefault(r.get("stage"), []).append(r)

    # `stage_label` is None both when there's no stage: label and for Done's own (label-less)
    # entry — only the former should suppress "current" everywhere, so check truthiness.
    # It can also be a label outside this order (e.g. `order` is SMALL_ORDER but the item
    # somehow carries a non-small stage label) — treated the same as "no current stage".
    current_idx = order_labels.index(stage_label) if stage_label and stage_label in order_labels else None
    segments = []
    for i, (label, name) in enumerate(order):
        suffix = label.split(":", 1)[1] if label else None
        stage_runs = runs_by_stage.get(suffix, [])
        entered = label in entered_labels or bool(stage_runs)
        if current_idx is not None:
            state = "done" if i < current_idx else "current" if i == current_idx else "ahead"
        else:
            state = "done" if entered else "ahead"
        costs = [_num(r.get("cost")) for r in stage_runs]
        known_costs = [c for c in costs if c is not None]
        segments.append({
            "name": name, "state": state, "entered": entered,
            "duration": durations.get(label), "ongoing": ongoing.get(label, False),
            "cost": sum(known_costs) if known_costs else None,
            "unknown_runs": sum(1 for c in costs if c is None),
            "color": (colors or {}).get(label),
        })
    return segments


def _totals_over_time(comments_by_number, totals):
    """R6/R7: fold every hq-run block from this domain's issues (open or closed — the
    comments were already fetched repo-wide) into `totals`, keyed by (Monday of its
    comment's created_at in UTC, model or "unknown", stage or "unknown"). A run with no
    usable cost is counted separately (`unknown`) rather than dropped."""
    for comments in comments_by_number.values():
        for r in _hq_runs(comments):
            created = datetime.strptime(r["created_at"], "%Y-%m-%dT%H:%M:%SZ")
            week = (created - timedelta(days=created.weekday())).strftime("%Y-%m-%d")
            model = r.get("model") or "unknown"
            stage = STAGE_NAMES.get(f"stage:{r.get('stage')}", r.get("stage") or "unknown")
            bucket = totals.setdefault((week, model, stage), {"cost": 0.0, "known": 0, "unknown": 0})
            cost = _num(r.get("cost"))
            if cost is None:
                bucket["unknown"] += 1
            else:
                bucket["cost"] += cost
                bucket["known"] += 1


def work_items():
    """Every domain (repos of OWNER's tagged `hq-domain`) with its open Work Items, and
    the cost totals-over-time across all of them: {domains: [{repo, full, items: [...]}],
    totals: [...]}. Uses ghcache so an unchanged domain costs nothing and a changed one
    costs one call, regardless of how many other domains exist. Each item still on an
    agent's stage is also checked for a stall (F7.10)."""
    domains = []
    totals = {}
    try:
        repos = ghcache.fetch_all("user/repos?per_page=100&affiliation=owner", run)
        for repo in repos:
            if repo["owner"]["login"] != owner():
                continue
            if repo["archived"] or "hq-domain" not in (repo.get("topics") or []):
                continue
            full = f"{owner()}/{repo['name']}"
            known.add(full)
            items = []
            parents = []
            issues = ghcache.fetch_all(f"repos/{full}/issues?state=open&per_page=100", run)
            for issue in issues:
                if "pull_request" in issue:
                    continue
                # A parent (F9) has no stage label — it's found by its sub-issues
                # instead, before the "not a Work Item" check below would drop it.
                if (issue.get("sub_issues_summary") or {}).get("total", 0) > 0:
                    subs = ghcache.fetch_all(
                        f"repos/{full}/issues/{issue['number']}/sub_issues?per_page=100", run)
                    open_subs = [s for s in subs if s["state"] == "open"]
                    if not open_subs:
                        run(["bash", os.path.join(HQ, "scripts", "parent.sh"),
                             "close-if-done", f"{full}#{issue['number']}"])
                        continue
                    summary = issue["sub_issues_summary"]
                    parents.append({
                        "number": issue["number"], "title": issue["title"],
                        "url": issue["html_url"], "parent": True, "stage": "Parent",
                        "waiting": [], "needs_you": False,
                        "done": summary["completed"], "total": summary["total"],
                        "parts": [],
                        "_refs": [(s["repository_url"].split("/repos/", 1)[-1], s["number"])
                                  for s in open_subs],
                    })
                    continue
                label_objs = issue["labels"]
                labels = [l["name"] for l in label_objs]
                stage_label_obj = next((l for l in label_objs if l["name"].startswith("stage:")), None)
                waiting = [l for l in labels if l.startswith("waiting:")]
                stage_label = stage_label_obj["name"] if stage_label_obj else None
                stage = STAGE_NAMES.get(stage_label, "")
                if not stage and not waiting:
                    continue  # no stage and nothing to do -> not a Work Item view needs
                if not stage:
                    stage = "0 Blocked" if "waiting:work" in waiting else "0 Stopped"
                items.append({
                    "number": issue["number"], "title": issue["title"], "stage": stage,
                    "stage_color": stage_label_obj["color"] if stage in STAGE_NAMES.values() else None,
                    "url": issue["html_url"], "waiting": waiting, "blocked_by": [],
                    "created_at": issue["created_at"], "stalled": False, "stall_reason": None,
                    "needs_you": stage.startswith("6 ") or "waiting:user" in waiting,
                    "size": "small" if "size:small" in labels else "normal",
                    "_stage_label": stage_label,
                })
            # Unconditional (not just for checkable/blocked items): needed even when a
            # domain has zero open items, so its closed-issue history still feeds
            # _totals_over_time (R6), and every item gets a cost/breakdown (R1, R4).
            comments_by_number = domain_comments(full)
            _totals_over_time(comments_by_number, totals)
            now = datetime.utcnow()
            # R11/V20: current colour off `labels`, not a `labeled` event's (historic) one.
            repo_labels = ghcache.fetch_all(f"repos/{full}/labels?per_page=100", run)
            stage_colors = {l["name"]: l["color"] for l in repo_labels if l["name"] in STAGE_NAMES}
            for it in items:
                runs = _hq_runs(comments_by_number.get(it["number"], []))
                it["cost"] = _cost_summary(runs)
                it["breakdown"] = _stage_breakdown(runs)
                events = ghcache.fetch_all(
                    f"repos/{full}/issues/{it['number']}/events?per_page=100", run)
                it["progress"] = _progress(
                    it.pop("_stage_label"), events, runs, now, colors=stage_colors,
                    order=SMALL_ORDER if it["size"] == "small" else None)
            # waiting:* (either kind) means the runner won't touch it either — not a stall.
            checkable = [it for it in items if it["stage"] in STAGE_LABEL and not it["waiting"]]
            blocked = [it for it in items if it["stage"] == "0 Blocked"]
            for it in checkable:
                comments = comments_by_number.get(it["number"], [])
                stalled, reason, parked = stall_info(full, it, comments)
                if stalled:
                    it["stalled"], it["stall_reason"], it["needs_you"] = True, reason, True
                    if parked:
                        it["waiting"].append("waiting:user")
            for it in blocked:
                reconcile_blockers(full, it, comments_by_number.get(it["number"], []))
            domains.append({"full": full, "repo": repo["name"], "items": items, "parents": parents})
    except ghcache.GhRefusal as e:
        raise _refusal(e.kind, e.detail)
    nest_parts(domains)
    totals_list = sorted(
        [{"week": w, "model": m, "stage": s,
          "cost": b["cost"] if b["known"] else None, "unknown": b["unknown"]}
         for (w, m, s), b in totals.items()],
        key=lambda t: t["week"], reverse=True)
    return {"domains": sorted(domains, key=lambda d: d["repo"]), "totals": totals_list}


def native_path(path):
    # Git Bash prints /c/Users/...; Windows Python and git need C:/Users/...
    m = re.match(r"^/([a-zA-Z])/(.*)$", path)
    return f"{m[1].upper()}:/{m[2]}" if os.name == "nt" and m else path


def port_open(port):
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", port)) == 0


def pick_port(preferred):
    """preferred if it's free and no tracked instance already claims it, else a free
    OS-assigned port (R2)."""
    claimed = {r["port"] for r in reviews.values() if r.get("port")}
    if preferred and not port_open(preferred) and preferred not in claimed:
        return preferred
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def stop_app(proc):
    if proc and proc.poll() is None:
        if os.name == "nt":  # npm and friends start children; end the whole tree
            run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], check=False)
        else:
            proc.terminate()


def start_instance(key):
    """Start the reviewed checkout's app from its .claude/launch.json (R2), with a
    detached watchdog as the dead-session backstop (R8). Returns {url, port}."""
    r = reviews.get(key)
    if not r:
        raise UserError("Open this Work Item with Review first.")
    if r.get("app"):
        stop_instance(key)
    launch = os.path.join(r["path"], ".claude", "launch.json")
    if not os.path.exists(launch):
        raise UserError("This repo has no app to start.")
    with open(launch, encoding="utf-8") as fh:
        config = json.load(fh)["configurations"][0]
    port = pick_port(config.get("port"))
    url = config.get("url") or f"http://localhost:{port}"
    exe = shutil.which(config["runtimeExecutable"]) or config["runtimeExecutable"]
    env = dict(os.environ, PORT=str(port))
    proc = subprocess.Popen([exe, *config.get("runtimeArgs", [])], cwd=r["path"], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **NO_WINDOW)
    heartbeat = os.path.join(tempfile.gettempdir(), f"hq-review-{key.replace('#', '-')}.heartbeat")
    with open(heartbeat, "w", encoding="utf-8"):
        pass
    detach = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW} \
        if os.name == "nt" else {"start_new_session": True}
    watchdog = subprocess.Popen(
        [sys.executable, os.path.join(HQ, "scripts", "app-watchdog.py"),
         str(proc.pid), heartbeat, str(APP_IDLE_TIMEOUT)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **detach)
    r.update(app=proc, port=port, url=url, heartbeat=heartbeat, watchdog=watchdog)
    return {"url": url, "port": port}


def stop_instance(key):
    """Stop the app and free its port immediately (R7)."""
    r = reviews.get(key)
    if not r or not r.get("app"):
        return
    stop_app(r["app"])
    if r.get("heartbeat"):
        try:
            os.remove(r["heartbeat"])
        except OSError:
            pass
    r.update(app=None, port=None, url=None, heartbeat=None, watchdog=None)


def restart_instance(key):
    """Pick up new commits on the branch under review, then start fresh (R6)."""
    r = reviews.get(key)
    if not r:
        raise UserError("Open this Work Item with Review first.")
    run(["git", "-C", r["path"], "pull", "--quiet"], check=False)
    stop_instance(key)
    return start_instance(key)


def ping_instance(key):
    """Keep a running instance's heartbeat fresh so the R8 backstop doesn't fire."""
    r = reviews.get(key)
    if r and r.get("heartbeat"):
        try:
            os.utime(r["heartbeat"], None)
        except OSError:
            pass


QA_HEADING_RE = re.compile(r"^## 5[a-z]?\. QA")


def latest_qa(comments):
    """The last QA comment, re-runs (`## 5b. QA (re-run)`) included; None if there isn't one."""
    qa = [c["body"] for c in comments if QA_HEADING_RE.match(c["body"])]
    return qa[-1] if qa else None


def after_merge(body):
    """The list under `### After merge` in a QA comment, up to the next heading; "" if none."""
    m = re.search(r"^### After merge[ \t]*\n(.*?)(?=^#|\Z)", body, re.M | re.S)
    return m.group(1).strip() if m else ""


BUILD_HEADING_RE = re.compile(r"^## 4[a-z]?\. Build")


def latest_build_comment(comments):
    """The latest Build comment's full body (size:small items have their evidence there,
    with no QA comment); "" if there isn't one."""
    builds = [c["body"] for c in comments if BUILD_HEADING_RE.match(c["body"])]
    return builds[-1] if builds else ""


def checkout_review(full, number):
    repo = full.split("/")[-1]
    res = run([BASH, "scripts/review-checkout.sh", repo, str(number)], check=False)
    if res.returncode == 2:
        raise UserError("There's no open pull request for this Work Item yet.")
    if res.returncode == 3:
        raise UserError("Your local copy has unsaved edits, so it wasn't touched:\n" + res.stderr)
    if res.returncode == 4:
        raise UserError("Your local copy has commits the PR branch doesn't, so it wasn't "
                        "touched:\n" + res.stderr)
    if res.returncode != 0:
        raise UserError(res.stderr.strip() or "Checkout failed.")
    kv = dict(line.split("=", 1) for line in res.stdout.splitlines() if "=" in line)
    kv["path"] = native_path(kv["path"])

    key = f"{repo}#{number}"
    if key in reviews:
        stop_instance(key)
    reviews[key] = {"default": kv["default"], "path": kv["path"], "pr": kv["pr"],
                    "app": None, "port": None, "url": None, "heartbeat": None, "watchdog": None}

    pr = kv["pr"]
    info = json.loads(run(["gh", "pr", "view", pr, "--repo", full,
                           "--json", "title,body,files"]).stdout)
    diff = run(["gh", "pr", "diff", pr, "--repo", full]).stdout
    comments = json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                               "--json", "comments"]).stdout)["comments"]
    qa = latest_qa(comments)
    files = [f["path"] for f in info["files"]]
    return {
        "key": key, "pr": pr, "pr_url": kv["pr_url"], "branch": kv["branch"],
        "path": kv["path"], "title": info["title"],
        "has_app": os.path.exists(os.path.join(kv["path"], ".claude", "launch.json")),
        "qa": qa, "after_merge": after_merge(qa) if qa else "", "diff": diff,
        "evidence": latest_build_comment(comments) if not qa else "",
        "claude_files": [f for f in files if f.startswith(".claude/")],
    }


def close_review(full, number):
    """Stop the app and put the local copy back on its default branch."""
    key = f"{full.split('/')[-1]}#{number}"
    if key not in reviews:
        return None
    stop_instance(key)
    r = reviews.pop(key)
    run(["git", "-C", r["path"], "checkout", r["default"]], check=False)
    run(["git", "-C", r["path"], "pull", "--quiet"], check=False)
    return r


def decide(full, number, decision, comment):
    """F8.6, the review skill's step 4: approve merges, reject goes back to Requirements
    (or Scope, on a size:small item)."""
    key = f"{full.split('/')[-1]}#{number}"
    if key not in reviews:
        raise UserError("Open this Work Item with Review first.")
    comment = comment.strip()
    if decision == "reject" and not comment:
        raise UserError("Say what's wrong, so the agents know what to change.")
    if decision not in ("approve", "reject"):
        raise UserError("Unknown decision.")
    pr = reviews[key]["pr"]
    # Back on the default branch first, so the merge can delete the PR branch.
    r = close_review(full, number)
    num = str(number)
    if decision == "approve":
        if comment:
            run(["gh", "issue", "comment", num, "--repo", full,
                 "--body", f"## 6. Review — user ✅\n\n{comment}"])
        # Outside any repo, so gh only touches GitHub; the local copy is pulled below.
        run(["gh", "pr", "merge", pr, "--repo", full, "--squash", "--delete-branch"],
            cwd=tempfile.gettempdir())
        run(["git", "-C", r["path"], "pull", "--quiet"], check=False)
        ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
        return {"message": f"Approved — PR #{pr} merged."}
    run(["gh", "issue", "comment", num, "--repo", full,
         "--body", f"## 6. Review — user ❌\n\n{comment}"])
    labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", num, "--repo", full,
                                                  "--json", "labels"]).stdout)["labels"]]
    next_stage = "stage:scope" if "size:small" in labels else "stage:requirements"
    # The rebuild reuses the open PR. The label change starts the next agent.
    run(["gh", "issue", "edit", num, "--repo", full,
         "--remove-label", "stage:review", "--add-label", next_stage])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": "Sent back to the agents with your comment."}


def stopped(full, number):
    """What a stopped Work Item is waiting for: its goal and the agent's last word."""
    data = json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                           "--json", "title,body,comments,labels"]).stdout)
    label_names = [l["name"] for l in data["labels"]]
    stage = [l for l in label_names if l.startswith("stage:")]
    default_stage = "stage:scope" if "size:small" in label_names else "stage:requirements"
    return {"title": data["title"], "goal": data["body"],
            "last": data["comments"][-1]["body"] if data["comments"] else "",
            "stage": stage[0] if stage else default_stage,
            "url": f"https://github.com/{full}/issues/{number}"}


def resume(full, number, comment):
    """Answer a stopped Work Item and start it moving again. A blocked Work Item
    (waiting:work, no stage: label) Answering a dropped-blocker 🛑 only settles that
    one blocker (R6): it stays parked at waiting:work if any other blocker is still
    open, rather than releasing straight to Requirements."""
    comment = comment.strip()
    if not comment:
        raise UserError("Write your answer first — it's what unblocks the agents.")
    labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                                  "--json", "labels"]).stdout)["labels"]]
    stage_labels = [l for l in labels if l.startswith("stage:")]
    run(["gh", "issue", "comment", str(number), "--repo", full,
         "--body", f"## Answer — user\n\n{comment}"])
    if not stage_labels and "waiting:work" in labels:
        comments = json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                   "--json", "comments"]).stdout)["comments"]
        refs = parse_blockers(comments)
        open_refs = [r for r in refs if blocker_state(r) == "open"]
        if open_refs:
            run(["gh", "issue", "edit", str(number), "--repo", full,
                 "--remove-label", "waiting:user"])
            ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
            joined = ", ".join(f"`{r}`" for r in open_refs)
            return {"message": f"Answer posted — still waiting on {joined}."}
    info = stopped(full, number)
    waiting = [l for l in labels if l.startswith("waiting:")]
    args = ["gh", "issue", "edit", str(number), "--repo", full,
            "--remove-label", info["stage"]]
    for l in waiting:
        args += ["--remove-label", l]
    run(args, check=False)  # the stage label may not be there to remove
    # Adding it back is what starts the agent: the workflow fires on a label being added.
    run(["gh", "issue", "edit", str(number), "--repo", full, "--add-label", info["stage"]])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": f"Answer posted — restarted at {info['stage'].split(':')[1]}."}


def ensure_label(full, name, color, description):
    """Same idiom as scripts/create-work-item.sh's ensure_label(): create the label in the
    target repo if it isn't already there. Needed here (R12) because a repo can be an
    existing domain whose labels were created before this one existed."""
    found = run(["gh", "label", "list", "--repo", full, "--search", name,
                 "--json", "name", "--jq", ".[].name"], check=False).stdout.split("\n")
    if name not in found:
        run(["gh", "label", "create", name, "--repo", full, "--color", color,
             "--description", description, "--force"])


def stop(full, number):
    """Park a Work Item before its next stage starts (R2): the runner's `waiting:` guard
    then skips it. Leaves the `stage:` label untouched (R3), so resume_stopped() knows
    where to pick back up."""
    labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                                  "--json", "labels"]).stdout)["labels"]]
    if not any(l.startswith("stage:") for l in labels):
        raise UserError("No running stage to stop — open the Issue to see what's going on.")
    if any(l.startswith("waiting:") for l in labels):
        raise UserError("Already waiting — nothing to stop.")
    ensure_label(full, "waiting:stopped", "C5DEF5", "Paused by the user, not the agents")
    run(["gh", "issue", "comment", str(number), "--repo", full, "--body", "Stopped by the user."])
    run(["gh", "issue", "edit", str(number), "--repo", full, "--add-label", "waiting:stopped"])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": "Stopped — parked before its next stage."}


def resume_stopped(full, number, reason):
    """Restart a user-stopped Work Item at the stage it was parked on (R6) — same
    remove/re-add idiom as resume()/restart(), which is what fires the runner's `labeled`
    webhook."""
    reason = reason.strip()
    if not reason:
        raise UserError("Say why you're resuming it, so the agents know what to change.")
    labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                                  "--json", "labels"]).stdout)["labels"]
              if l["name"].startswith("stage:")]
    if not labels:
        raise UserError("No stage to resume — open the Issue to see what's going on.")
    stage = labels[0]
    run(["gh", "issue", "comment", str(number), "--repo", full,
         "--body", f"## Resume — user\n\n{reason}"])
    run(["gh", "issue", "edit", str(number), "--repo", full,
         "--remove-label", stage, "--remove-label", "waiting:stopped"])
    run(["gh", "issue", "edit", str(number), "--repo", full, "--add-label", stage])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": f"Resumed at {stage.split(':')[1]}."}


def restart(full, number, reason, target=None):
    """Retry a stalled Work Item, at its current stage or an earlier one — same idiom as
    resume(): remove then re-add the stage: label, which is what starts the agent."""
    reason = reason.strip()
    if not reason:
        raise UserError("Say why you're restarting it, so the agents know what to change.")
    if target is not None and target not in RESTART_STAGES:
        raise UserError(f"'{target}' isn't a stage you can restart at.")
    all_labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                                      "--json", "labels"]).stdout)["labels"]]
    labels = [l for l in all_labels if l.startswith("stage:")]
    if not labels:
        raise UserError("No stage to restart — open the Issue to see what's going on.")
    stage = labels[0]
    # A parked Work Item (stalled, or stopped by the user) keeps its waiting: label, and
    # the runner skips anything with one — so Restart has to clear it or nothing runs.
    # waiting:work stays: that one means a blocker hasn't merged yet.
    unpark = [l for l in all_labels if l in ("waiting:user", "waiting:stopped")]
    run(["gh", "issue", "comment", str(number), "--repo", full, "--body", reason])
    new_stage = f"stage:{target}" if target else stage
    edit = ["gh", "issue", "edit", str(number), "--repo", full, "--remove-label", stage]
    for l in unpark:
        edit += ["--remove-label", l]
    run(edit)
    run(["gh", "issue", "edit", str(number), "--repo", full, "--add-label", new_stage])
    return {"message": f"Restarted at {new_stage.split(':')[1]}."}


def drop(full, number, reason):
    """Throw a Work Item away: PR closed, branch gone, Issue closed as not planned."""
    close_review(full, number)  # in case it was checked out
    res = run([BASH, "scripts/drop-work-item.sh", full.split("/")[-1], str(number),
               reason.strip()], check=False)
    if res.returncode == 2:
        raise UserError("That Work Item doesn't exist any more.")
    if res.returncode != 0:
        raise UserError(res.stderr.strip() or "Couldn't drop it.")
    pr = [l.split("=")[1] for l in res.stdout.splitlines() if l.startswith("closed_pr=")]
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": "Dropped." + (f" PR #{pr[0]} closed and its branch deleted." if pr else "")}


def restart_hq():
    """Same as `python dashboard/ctl.py restart`, but from inside a request: refuses at
    once (R3/R9) if the working copy is dirty, otherwise hands off to a detached `ctl.py
    restart` so the new server survives this process exiting (R4)."""
    reason = ctl.ensure_branch("main")
    if reason:
        raise UserError(reason)
    kwargs = {"cwd": HQ, "stdin": subprocess.DEVNULL, "stderr": subprocess.STDOUT,
              "env": dict(os.environ, HQ_NO_BROWSER="1")}
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True
    with open(ctl.RESTART_OUTCOME_FILE, "w", encoding="utf-8") as outcome:
        subprocess.Popen([sys.executable, ctl.__file__, "restart"], stdout=outcome, **kwargs)
    return {"boot": os.getpid()}


def restart_hq_status():
    """Polled by the page while a restart is in flight (R6/R7/R9/R10): `boot` changes
    once the new process has taken over; `outcome` is ctl's own last printed line."""
    try:
        with open(ctl.RESTART_OUTCOME_FILE, encoding="utf-8") as fh:
            lines = [l for l in fh.read().splitlines() if l.strip()]
    except FileNotFoundError:
        lines = []
    return {"boot": os.getpid(), "outcome": lines[-1] if lines else ""}


class UserError(Exception):
    pass


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind="application/json", extra=None):
        data = (body if isinstance(body, str) else json.dumps(body)).encode("utf-8")
        self.send_response(code)
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            self.send(200, PAGE_HTML, "text/html; charset=utf-8")
        elif parsed.path == "/api/items":
            try:
                # The budget rides along as a header: GitHub reports it on every
                # response we already make, so showing it costs no extra call.
                r = ghcache.rate()
                extra = {"X-HQ-Rate": f"{r['remaining']},{r['limit']},{r['reset']}"} if r else None
                self.send(200, work_items(), extra=extra)
            except RefusalError as e:
                self.send(200, {"refusal": {"kind": e.kind, "message": e.message}})
            except (subprocess.CalledProcessError, RuntimeError) as e:
                self.send(500, {"error": (getattr(e, "stderr", None) or str(e)).strip()})
        elif parsed.path == "/api/branch":
            # This process's own checkout — never cached, so a review instance
            # (its own process, its own HQ constant) reports its own branch (R5).
            try:
                branch = run(["git", "-C", HQ, "rev-parse", "--abbrev-ref", "HEAD"]).stdout.strip()
                self.send(200, {"branch": branch})
            except subprocess.CalledProcessError as e:
                self.send(500, {"error": (e.stderr or str(e)).strip()})
        elif parsed.path == "/api/hq/restart":
            self.send(200, restart_hq_status())
        elif parsed.path == "/review-window":
            qs = parse_qs(parsed.query)
            full = (qs.get("repo") or [""])[0]
            number = (qs.get("number") or [""])[0]
            key = f"{full.split('/')[-1]}#{number}"
            r = reviews.get(key)
            if not r or not r.get("url"):
                return self.send(404, "Not found", "text/plain")
            html = (
                "<!doctype html><html><head><meta charset=\"utf-8\">"
                f"<title>{escape(key)}</title>"
                "<style>html,body{margin:0;height:100%}iframe{border:0;width:100%;height:100%}</style>"
                f"</head><body><iframe src=\"{escape(r['url'])}\"></iframe></body></html>"
            )
            self.send(200, html, "text/html; charset=utf-8")
        else:
            self.send(404, "Not found", "text/plain")

    def do_POST(self):
        # The custom header forces a CORS preflight, which this server never answers,
        # so other websites open in your browser can't press these buttons.
        if self.headers.get("X-HQ") != "1":
            return self.send(403, {"error": "Forbidden"})
        if self.path == "/api/hq/restart":
            try:
                return self.send(200, restart_hq())
            except UserError as e:
                return self.send(400, {"error": str(e)})
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            full, number = body["repo"], int(body["number"])
            if full not in known and full not in {d["full"] for d in work_items()["domains"]}:
                raise UserError(f"{full} isn't one of your domains.")
            key = f"{full.split('/')[-1]}#{number}"
            if self.path == "/api/review":
                self.send(200, checkout_review(full, number))
            elif self.path == "/api/review/close":
                close_review(full, number)
                self.send(200, {"ok": True})
            elif self.path == "/api/review/app/start":
                self.send(200, start_instance(key))
            elif self.path == "/api/review/app/stop":
                stop_instance(key)
                self.send(200, {"ok": True})
            elif self.path == "/api/review/app/restart":
                self.send(200, restart_instance(key))
            elif self.path == "/api/review/app/ping":
                ping_instance(key)
                self.send(200, {"ok": True})
            elif self.path == "/api/drop":
                self.send(200, drop(full, number, body.get("comment", "")))
            elif self.path == "/api/stopped":
                self.send(200, stopped(full, number))
            elif self.path == "/api/resume":
                self.send(200, resume(full, number, body.get("comment", "")))
            elif self.path == "/api/stop":
                self.send(200, stop(full, number))
            elif self.path == "/api/resume-stopped":
                self.send(200, resume_stopped(full, number, body.get("reason", "")))
            elif self.path == "/api/restart":
                self.send(200, restart(full, number, body.get("reason", ""), body.get("stage")))
            elif self.path == "/api/review/decide":
                self.send(200, decide(full, number, body.get("decision"), body.get("comment", "")))
            else:
                self.send(404, {"error": "Not found"})
        except UserError as e:
            self.send(400, {"error": str(e)})
        except (subprocess.CalledProcessError, KeyError, ValueError) as e:
            detail = getattr(e, "stderr", None) or str(e)
            self.send(500, {"error": detail.strip()})

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    # localhost only: the buttons act on your repos.
    print(f"HQ dashboard: http://localhost:{PORT}", flush=True)
    try:
        ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
    finally:
        for r in reviews.values():
            stop_app(r["app"])
