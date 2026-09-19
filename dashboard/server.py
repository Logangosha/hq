"""HQ review dashboard (F8.4): a local page listing every open Work Item, with the
ones that need you on top. Runs on your computer so later buttons (F8.5, F8.6) can
run HQ's scripts here.

Usage: python dashboard/server.py        then open http://localhost:8765
"""
import json
import os
import shutil
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


def work_items():
    """scripts/list-work-items.sh, as JSON: [{repo, full, items: [...]}]."""
    out = subprocess.run(
        [BASH, "scripts/list-work-items.sh"], cwd=HQ,
        capture_output=True, text=True, encoding="utf-8", check=True,
    ).stdout
    domains = []
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "DOMAIN":
            domains.append({"full": f[1], "repo": f[1].split("/")[-1], "items": []})
        elif len(f) >= 5 and domains:
            waiting = [w for w in (f[5] if len(f) > 5 else "").split(",") if w]
            stage = f[3]
            domains[-1]["items"].append({
                "number": int(f[1]), "title": f[2], "stage": stage, "url": f[4],
                "waiting": waiting,
                "needs_you": stage.startswith("6 ") or "waiting:user" in waiting,
            })
    return domains


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body, kind):
        data = body.encode("utf-8")
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
                self.send(200, json.dumps(work_items()), "application/json")
            except subprocess.CalledProcessError as e:
                self.send(500, json.dumps({"error": (e.stderr or str(e)).strip()}), "application/json")
        else:
            self.send(404, "Not found", "text/plain")

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    # localhost only: the buttons to come will act on your repos.
    print(f"HQ dashboard: http://localhost:{PORT}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
