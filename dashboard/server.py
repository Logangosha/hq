"""HQ review dashboard: a local page listing every open Work Item, with the ones that
need you on top (F8.4). Review opens one: its branch is checked out on this computer,
its app started, and its code changes shown (F8.5); then you approve or reject it with
a comment (F8.6). Runs here, not on GitHub, so the
buttons can use HQ's scripts and your local copies of the repos.

Usage: python dashboard/server.py        then open http://localhost:8765
"""
import datetime
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import ghcache

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(HQ, "dashboard", "index.html")
PORT = int(os.environ.get("PORT", "8765"))
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
reviews = {}  # "<repo>#<n>" -> {"default", "path", "app": Popen or None}
known = set()  # owner/repo of every domain, from the last listing


def run(args, cwd=HQ, check=True):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True,
                          encoding="utf-8", check=check)


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
            reset = datetime.datetime.fromtimestamp(int(detail)).strftime("%I:%M %p").lstrip("0")
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


def work_items():
    """Every domain (repos of OWNER's tagged `hq-domain`) with its open Work Items, as
    JSON: [{repo, full, items: [...]}]. Uses ghcache so an unchanged domain costs nothing
    and a changed one costs one call, regardless of how many other domains exist."""
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
                labels = [l["name"] for l in issue["labels"]]
                stage_label = next((l for l in labels if l.startswith("stage:")), None)
                waiting = [l for l in labels if l.startswith("waiting:")]
                stage = STAGE_NAMES.get(stage_label, "")
                if not stage and not waiting:
                    continue  # no stage and nothing to do -> not a Work Item view needs
                if not stage:
                    stage = "0 Stopped"
                items.append({
                    "number": issue["number"], "title": issue["title"], "stage": stage,
                    "url": issue["html_url"], "waiting": waiting,
                    "needs_you": stage.startswith("6 ") or "waiting:user" in waiting,
                })
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


def start_app(path):
    """Start the repo's app from its .claude/launch.json. Returns (url, process)."""
    launch = os.path.join(path, ".claude", "launch.json")
    if not os.path.exists(launch):
        return None, None
    with open(launch, encoding="utf-8") as fh:
        config = json.load(fh)["configurations"][0]
    port = config.get("port")
    url = config.get("url") or (f"http://localhost:{port}" if port else None)
    if port and port_open(port):
        return url, None  # already running (reviewing HQ itself lands here)
    exe = shutil.which(config["runtimeExecutable"]) or config["runtimeExecutable"]
    proc = subprocess.Popen([exe, *config.get("runtimeArgs", [])], cwd=path,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return url, proc


def stop_app(proc):
    if proc and proc.poll() is None:
        if os.name == "nt":  # npm and friends start children; end the whole tree
            run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], check=False)
        else:
            proc.terminate()


def open_review(full, number):
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
        stop_app(reviews[key]["app"])
    app_url, proc = start_app(kv["path"])
    reviews[key] = {"default": kv["default"], "path": kv["path"], "app": proc, "pr": kv["pr"]}

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
        "path": kv["path"], "title": info["title"], "app_url": app_url,
        "qa": qa[-1] if qa else None, "diff": diff,
        "claude_files": [f for f in files if f.startswith(".claude/")],
    }


def close_review(full, number):
    """Stop the app and put the local copy back on its default branch."""
    key = f"{full.split('/')[-1]}#{number}"
    r = reviews.pop(key, None)
    if not r:
        return None
    stop_app(r["app"])
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
        return {"message": f"Approved — PR #{pr} merged."}
    run(["gh", "issue", "comment", num, "--repo", full,
         "--body", f"## 6. Review — user ❌\n\n{comment}"])
    # The rebuild reuses the open PR. The label change starts the requirements agent.
    run(["gh", "issue", "edit", num, "--repo", full,
         "--remove-label", "stage:review", "--add-label", "stage:requirements"])
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
    return {"message": f"Answer posted — restarted at {info['stage'].split(':')[1]}."}


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
        if self.path in ("/", "/index.html"):
            self.send(200, PAGE_HTML, "text/html; charset=utf-8")
        elif self.path == "/api/items":
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
            if self.path == "/api/review":
                self.send(200, open_review(full, number))
            elif self.path == "/api/review/close":
                close_review(full, number)
                self.send(200, {"ok": True})
            elif self.path == "/api/drop":
                self.send(200, drop(full, number, body.get("comment", "")))
            elif self.path == "/api/stopped":
                self.send(200, stopped(full, number))
            elif self.path == "/api/resume":
                self.send(200, resume(full, number, body.get("comment", "")))
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
