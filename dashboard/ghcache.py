"""Shared conditional-GET cache for the dashboard's GitHub REST polling.

Every dashboard process (one per port) reads and writes the same JSON file, so two
dashboards polling the same URL only cost GitHub calls once between them. A cached
entry younger than FRESH_SECONDS (below the fastest poll cadence, index.html's
nextDelay()) is returned with no network call at all; otherwise a conditional GET
(If-None-Match) either confirms the cached body (304, free) or replaces it (200).

Only plain REST list endpoints (repos/{owner}/{repo}/issues, user/repos, ...)
support ETag/304 like this — the Search API doesn't, so it must not be fetched here.
"""
import hashlib
import json
import os
import tempfile
import time
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

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


def _remember_rate(cache, headers):
    """Keep the budget GitHub reports on every response, so showing it costs no call."""
    if "x-ratelimit-limit" not in headers:
        return
    cache["_rate"] = {
        "limit": int(headers["x-ratelimit-limit"]),
        "remaining": int(headers.get("x-ratelimit-remaining", 0)),
        "reset": int(headers.get("x-ratelimit-reset", 0)),
        "at": time.time(),
    }


def rate():
    """The last budget GitHub reported, or None. Shared by every dashboard process."""
    return _load().get("_rate")


def invalidate(url):
    """Drop url's cached entry so the next fetch() can't serve a pre-mutation body."""
    cache = _load()
    if cache.pop(url, None) is not None:
        _save(cache)


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
    _remember_rate(cache, headers)

    if status == 304 and entry:
        entry["fetched_at"] = now
        if headers.get("link"):
            entry["link"] = headers["link"]
        cache[url] = entry
        _save(cache)
        return json.loads(entry["body"]), entry.get("link")

    if status in (401, 403, 429):
        _save(cache)  # keep the budget this response reported before giving up
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


def _page_after(url):
    """url with page=<current, default 1>+1, per_page as int (default 30), other params kept."""
    split = urlsplit(url)
    params = dict(parse_qsl(split.query))
    page = int(params.get("page", 1))
    per_page = int(params.get("per_page", 30))
    params["page"] = str(page + 1)
    params["per_page"] = str(per_page)
    return urlunsplit(split._replace(query=urlencode(params))), per_page


def fetch_all(url, run):
    """Like fetch(), but follows Link: rel="next" and returns every page's items combined.

    A 304 carries no Link, so a full last page's cached "no next" may be stale; the next
    page is probed.
    """
    items = []
    while url:
        page, link = fetch(url, run)
        items.extend(page)
        next_url, per_page = _page_after(url)
        url = None
        if link:
            for part in link.split(","):
                if 'rel="next"' in part:
                    url = part.split(";")[0].strip().strip("<>")
                    # gh api takes paths, not full URLs
                    url = url.split("api.github.com/", 1)[-1]
        if not url and len(page) >= per_page:
            url = next_url
    return items
