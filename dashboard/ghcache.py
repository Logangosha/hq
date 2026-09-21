"""Shared conditional-GET cache for the dashboard's GitHub REST polling.

Every dashboard process (one per port) reads and writes the same JSON file, so two
dashboards polling the same URL only cost GitHub calls once between them. A cached
entry younger than FRESH_SECONDS (below the fastest poll cadence, index.html's
nextDelay()) is returned with no network call at all; otherwise a conditional GET
(If-None-Match) either confirms the cached body (304, free) or replaces it (200).

Only plain REST list endpoints (repos/{owner}/{repo}/issues, users/{owner}/repos, ...)
support ETag/304 like this — the Search API doesn't, so it must not be fetched here.
"""
import hashlib
import json
import os
import tempfile
import time

FRESH_SECONDS = 4  # below index.html's fastest poll cadence (5s)

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE_PATH = os.path.join(
    tempfile.gettempdir(),
    f"hq-dashboard-cache-{hashlib.sha1(HQ.encode()).hexdigest()[:12]}.json",
)


def _load():
    try:
        with open(CACHE_PATH, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def _save(cache):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE_PATH))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(cache, fh)
        os.replace(tmp, CACHE_PATH)
    except OSError:
        if os.path.exists(tmp):
            os.remove(tmp)


class GhRefusal(Exception):
    """gh refused the request outright: rate limit, bad/expired token, or no network."""
    def __init__(self, kind, detail=""):
        super().__init__(f"{kind} {detail}".strip())
        self.kind = kind
        self.detail = detail


def classify(stderr):
    """(kind, detail) for a failed `gh` invocation's stderr: rate_limit, auth, or offline."""
    err = (stderr or "").lower()
    if "rate limit" in err:
        return "rate_limit", ""
    if "bad credentials" in err or "http 401" in err or "gh auth login" in err:
        return "auth", ""
    return "offline", ""


def _parse(raw):
    """gh api ... -i output -> (status, headers, body_text)."""
    head, _, body = raw.partition("\n\n")
    lines = head.splitlines()
    status = int(lines[0].split()[1])
    headers = {}
    for line in lines[1:]:
        if ":" in line:
            k, _, v = line.partition(":")
            headers[k.strip().lower()] = v.strip()
    return status, headers, body.strip()


def fetch(url, run):
    """Return (body_json, link_header) for a GitHub REST GET, using the shared cache.

    `run` is server.py's subprocess runner: run(args, check=False) -> CompletedProcess.
    Raises GhRefusal, not RuntimeError, for a rate limit, bad/expired token, or no network.
    """
    cache = _load()
    entry = cache.get(url)
    now = time.time()
    if entry and now - entry["fetched_at"] < FRESH_SECONDS:
        return json.loads(entry["body"]), entry.get("link")

    args = ["gh", "api", url, "-i"]
    if entry and entry.get("etag"):
        args += ["-H", f"If-None-Match: {entry['etag']}"]
    res = run(args, check=False)
    if res.returncode != 0 and not res.stdout.startswith("HTTP/"):
        raise GhRefusal(*classify(res.stderr))  # gh never got an HTTP response at all
    status, headers, body = _parse(res.stdout)

    if status == 304 and entry:
        entry["fetched_at"] = now
        cache[url] = entry
        _save(cache)
        return json.loads(entry["body"]), entry.get("link")

    if status == 401:
        raise GhRefusal("auth")
    if status in (403, 429) and headers.get("x-ratelimit-remaining") == "0":
        raise GhRefusal("rate_limit", headers.get("x-ratelimit-reset", ""))

    if status != 200:
        raise RuntimeError(f"GitHub API error for {url}: {status} {body[:200]}")

    cache[url] = {
        "fetched_at": now,
        "etag": headers.get("etag"),
        "link": headers.get("link"),
        "body": body,
    }
    _save(cache)
    return json.loads(body), headers.get("link")


def fetch_all(url, run):
    """Like fetch(), but follows Link: rel="next" and returns every page's items combined."""
    items = []
    while url:
        page, link = fetch(url, run)
        items.extend(page)
        url = None
        if link:
            for part in link.split(","):
                if 'rel="next"' in part:
                    url = part.split(";")[0].strip().strip("<>")
                    # gh api takes paths, not full URLs
                    url = url.split("api.github.com/", 1)[-1]
    return items
