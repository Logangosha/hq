"""HQ review dashboard: a local page listing every open Work Item, with the ones that
need you on top (F8.4). Review opens one: its branch is checked out on this computer,
its app started, and its code changes shown (F8.5). Runs here, not on GitHub, so the
buttons can use HQ's scripts and your local copies of the repos.

Usage: python dashboard/server.py        then open http://localhost:8765
"""
import json
import os
import shutil
import socket
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(HQ, "dashboard", "index.html")
PORT = int(os.environ.get("PORT", "8765"))


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


def work_items():
    """scripts/list-work-items.sh, as JSON: [{repo, full, items: [...]}]."""
    domains = []
    for line in run([BASH, "scripts/list-work-items.sh"]).stdout.splitlines():
        f = line.split("\t")
        if f[0] == "DOMAIN":
            domains.append({"full": f[1], "repo": f[1].split("/")[-1], "items": []})
            known.add(f[1])
        elif len(f) >= 5 and domains:
            waiting = [w for w in (f[5] if len(f) > 5 else "").split(",") if w]
            stage = f[3]
            domains[-1]["items"].append({
                "number": int(f[1]), "title": f[2], "stage": stage, "url": f[4],
                "waiting": waiting,
                "needs_you": stage.startswith("6 ") or "waiting:user" in waiting,
            })
    return domains


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
    if res.returncode != 0:
        raise UserError(res.stderr.strip() or "Checkout failed.")
    kv = dict(line.split("=", 1) for line in res.stdout.splitlines() if "=" in line)

    key = f"{repo}#{number}"
    if key in reviews:
        stop_app(reviews[key]["app"])
    app_url, proc = start_app(kv["path"])
    reviews[key] = {"default": kv["default"], "path": kv["path"], "app": proc}

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
        return
    stop_app(r["app"])
    run(["git", "-C", r["path"], "checkout", r["default"]], check=False)
    run(["git", "-C", r["path"], "pull", "--quiet"], check=False)


class UserError(Exception):
    pass


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind="application/json"):
        data = (body if isinstance(body, str) else json.dumps(body)).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            with open(PAGE, encoding="utf-8") as fh:
                self.send(200, fh.read(), "text/html; charset=utf-8")
        elif self.path == "/api/items":
            try:
                self.send(200, work_items())
            except subprocess.CalledProcessError as e:
                self.send(500, {"error": (e.stderr or str(e)).strip()})
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
