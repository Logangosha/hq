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
    "stage:requirements": "1 Requirements",
    "stage:verification": "2 Verification",
    "stage:plan": "3 Plan",
    "stage:build": "4 Build",
    "stage:qa": "5 QA",
    "stage:review": "6 Human review",
}


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
    "1 Requirements": "stage:requirements", "2 Verification": "stage:verification",
    "3 Plan": "stage:plan", "4 Build": "stage:build", "5 QA": "stage:qa",
}
STAGE_AGENT = {
    "1 Requirements": "requirements", "2 Verification": "verification",
    "3 Plan": "planner", "4 Build": "builder", "5 QA": "qa",
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


BLOCKER_RE = re.compile(r"Blocked by `([^`]+)`")


def parse_blocker(comments):
    """The `owner/repo#N` a blocked Work Item names in its creation comment, or None."""
    for c in comments:
        m = BLOCKER_RE.search(c["body"])
        if m:
            return m.group(1)
    return None


def reconcile_blocker(full, it):
    """Release a blocked Work Item once its blocker closes (R4-R6): merged starts
    Requirements; closed without merging surfaces the drop for the user instead of
    releasing on its own. Runs from the same poll as stall_info, so a PR merged
    straight on GitHub is picked up too, not only one merged through the dashboard."""
    ref = it["blocked_by"]
    if not ref or "waiting:user" in it["waiting"]:
        return  # nothing recorded, or already surfaced and parked for the user
    bfull, bnum = ref.rsplit("#", 1)
    res = run(["gh", "issue", "view", bnum, "--repo", bfull, "--json", "state,stateReason"],
              check=False)
    if res.returncode != 0:
        return  # blocker issue gone or inaccessible — leave it parked, don't guess
    info = json.loads(res.stdout)
    if info["state"] != "CLOSED":
        return
    number = str(it["number"])
    if info["stateReason"] == "COMPLETED":
        run(["gh", "issue", "comment", number, "--repo", full,
             "--body", f"Blocker `{ref}` merged. Starting Requirements."])
        # Two calls, remove then add (same idiom as resume()): the labeled event that
        # starts the requirements agent must not still show waiting:work, or the
        # runner's waiting: guard skips it.
        run(["gh", "issue", "edit", number, "--repo", full, "--remove-label", "waiting:work"])
        run(["gh", "issue", "edit", number, "--repo", full, "--add-label", "stage:requirements"])
        it["stage"], it["waiting"] = "1 Requirements", []
    else:
        run(["gh", "issue", "comment", number, "--repo", full,
             "--body", f"🛑 Blocker `{ref}` was closed without merging. A person needs to "
                       "decide: release this Work Item (Answer) or drop it too."])
        run(["gh", "issue", "edit", number, "--repo", full, "--add-label", "waiting:user"])
        it["waiting"].append("waiting:user")
        it["needs_you"] = True


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


def work_items():
    """Every domain (repos of OWNER's tagged `hq-domain`) with its open Work Items, as
    JSON: [{repo, full, items: [...]}]. Uses ghcache so an unchanged domain costs nothing
    and a changed one costs one call, regardless of how many other domains exist. Each
    item still on an agent's stage is also checked for a stall (F7.10)."""
    domains = []
    try:
        repos = ghcache.fetch_all(f"users/{owner()}/repos?per_page=100", run)
        for repo in repos:
            if repo["archived"] or "hq-domain" not in (repo.get("topics") or []):
                continue
            full = f"{owner()}/{repo['name']}"
            known.add(full)
            items = []
            issues = ghcache.fetch_all(f"repos/{full}/issues?state=open&per_page=100", run)
            for issue in issues:
                if "pull_request" in issue:
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
                    "url": issue["html_url"], "waiting": waiting, "blocked_by": None,
                    "created_at": issue["created_at"], "stalled": False, "stall_reason": None,
                    "needs_you": stage.startswith("6 ") or "waiting:user" in waiting,
                })
            # waiting:* (either kind) means the runner won't touch it either — not a stall.
            checkable = [it for it in items if it["stage"] in STAGE_LABEL and not it["waiting"]]
            blocked = [it for it in items if it["stage"] == "0 Blocked"]
            if checkable or blocked:
                comments_by_number = domain_comments(full)
                for it in checkable:
                    comments = comments_by_number.get(it["number"], [])
                    stalled, reason, parked = stall_info(full, it, comments)
                    if stalled:
                        it["stalled"], it["stall_reason"], it["needs_you"] = True, reason, True
                        if parked:
                            it["waiting"].append("waiting:user")
                for it in blocked:
                    it["blocked_by"] = parse_blocker(comments_by_number.get(it["number"], []))
                    reconcile_blocker(full, it)
            domains.append({"full": full, "repo": repo["name"], "items": items})
    except ghcache.GhRefusal as e:
        raise _refusal(e.kind, e.detail)
    return sorted(domains, key=lambda d: d["repo"])


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
    qa = [c["body"] for c in comments if c["body"].startswith("## 5. QA")]
    files = [f["path"] for f in info["files"]]
    return {
        "key": key, "pr": pr, "pr_url": kv["pr_url"], "branch": kv["branch"],
        "path": kv["path"], "title": info["title"],
        "has_app": os.path.exists(os.path.join(kv["path"], ".claude", "launch.json")),
        "qa": qa[-1] if qa else None, "diff": diff,
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
    """F8.6, the review skill's step 4: approve merges, reject goes back to Requirements."""
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
    # The rebuild reuses the open PR. The label change starts the requirements agent.
    run(["gh", "issue", "edit", num, "--repo", full,
         "--remove-label", "stage:review", "--add-label", "stage:requirements"])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": "Sent back to the agents with your comment."}


def stopped(full, number):
    """What a stopped Work Item is waiting for: its goal and the agent's last word."""
    data = json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                           "--json", "title,body,comments,labels"]).stdout)
    stage = [l["name"] for l in data["labels"] if l["name"].startswith("stage:")]
    return {"title": data["title"], "goal": data["body"],
            "last": data["comments"][-1]["body"] if data["comments"] else "",
            "stage": stage[0] if stage else "stage:requirements",
            "url": f"https://github.com/{full}/issues/{number}"}


def resume(full, number, comment):
    """Answer a stopped Work Item and start it moving again."""
    comment = comment.strip()
    if not comment:
        raise UserError("Write your answer first — it's what unblocks the agents.")
    info = stopped(full, number)
    run(["gh", "issue", "comment", str(number), "--repo", full,
         "--body", f"## Answer — user\n\n{comment}"])
    waiting = [l for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                          "--json", "labels"]).stdout)["labels"]
               if l["name"].startswith("waiting:")]
    args = ["gh", "issue", "edit", str(number), "--repo", full,
            "--remove-label", info["stage"]]
    for l in waiting:
        args += ["--remove-label", l["name"]]
    run(args, check=False)  # the stage label may not be there to remove
    # Adding it back is what starts the agent: the workflow fires on a label being added.
    run(["gh", "issue", "edit", str(number), "--repo", full, "--add-label", info["stage"]])
    ghcache.invalidate(f"repos/{full}/issues?state=open&per_page=100")
    return {"message": f"Answer posted — restarted at {info['stage'].split(':')[1]}."}


def restart(full, number, reason, target=None):
    """Retry a stalled Work Item, at its current stage or an earlier one — same idiom as
    resume(): remove then re-add the stage: label, which is what starts the agent."""
    reason = reason.strip()
    if not reason:
        raise UserError("Say why you're restarting it, so the agents know what to change.")
    if target is not None and target not in RESTART_STAGES:
        raise UserError(f"'{target}' isn't a stage you can restart at.")
    labels = [l["name"] for l in json.loads(run(["gh", "issue", "view", str(number), "--repo", full,
                                                  "--json", "labels"]).stdout)["labels"]
              if l["name"].startswith("stage:")]
    if not labels:
        raise UserError("No stage to restart — open the Issue to see what's going on.")
    stage = labels[0]
    run(["gh", "issue", "comment", str(number), "--repo", full, "--body", reason])
    new_stage = f"stage:{target}" if target else stage
    run(["gh", "issue", "edit", str(number), "--repo", full, "--remove-label", stage])
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
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            full, number = body["repo"], int(body["number"])
            if full not in known and full not in {d["full"] for d in work_items()}:
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
