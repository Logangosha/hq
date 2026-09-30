"""What a page can do: its agents and workflows (HQ's plus the domain's own, the domain's
winning on a name clash), read from files — HQ's from this checkout, a domain's from
GitHub. On a domain page HQ's stage agents are left out and HQ's general ones carry
`general`. Formats: .claude/agents/README.md (agent cards), orchestration/workflows.md."""
import base64
import importlib.util
import os
import re
import tempfile
from pathlib import Path

import ghcache

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("agent_cards", os.path.join(HQ, "scripts", "agent-cards.py"))
agent_cards = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(agent_cards)

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def _remote(full, path, run):
    """(name, text) of each .md file in `path` of repo `full`; [] if the folder is absent."""
    listing, _ = ghcache.fetch(f"repos/{full}/contents/{path}", run, missing_ok=True)
    out = []
    for f in listing or []:
        if f.get("type") != "file" or not f["name"].endswith(".md") or f["name"] == "README.md":
            continue
        body, _ = ghcache.fetch(f"repos/{full}/contents/{path}/{f['name']}", run, missing_ok=True)
        if body and body.get("content") is not None:
            out.append((f["name"][:-3], base64.b64decode(body["content"]).decode("utf-8", "replace")))
    return out


def _local(path):
    d = Path(HQ) / path
    return [(f.stem, f.read_text(encoding="utf-8")) for f in sorted(d.glob("*.md")) if f.name != "README.md"] \
        if d.is_dir() else []


def _files(full, hq_full, path, run):
    """HQ's files, then `full`'s own over them (skipped when `full` is HQ itself)."""
    files = dict(_local(path))
    if full != hq_full:
        files.update(dict(_remote(full, path, run)))
    return files


def _card(stem, text):
    with tempfile.TemporaryDirectory() as tmp:
        p = Path(tmp) / f"{stem}.md"
        p.write_text(text, encoding="utf-8")
        e = agent_cards.parse(p)
    e["id"] = stem
    e["file"] = f".claude/agents/{stem}.md"
    e["description"] = agent_cards.frontmatter(text).get("description") or ""
    if e["errors"] or e["fallback"]:
        # A missing or malformed card falls back whole: name and description only.
        e.update(display_name=e["name"], icon="smart_toy", inputs=None, output=None, shortcuts=[])
        e["purpose"] = agent_cards.frontmatter(text).get("description") or ""
    return e


def agents(full, hq_full, run):
    """Cards for the agents of page `full`, sorted by id. On a domain's page, HQ's stage
    agents are left out and HQ's general ones are marked `general` (the domain's own win)."""
    if full == hq_full:
        files = _files(full, hq_full, ".claude/agents", run)
        return [_card(stem, files[stem]) for stem in sorted(files)]
    stage = stage_agents()
    cards = {s: dict(_card(s, t), general=True) for s, t in _local(".claude/agents") if s not in stage}
    cards.update({s: _card(s, t) for s, t in _remote(full, ".claude/agents", run)})
    return [cards[s] for s in sorted(cards)]


def _rows(section):
    out = [[c.strip().replace("`", "") for c in l.strip().strip("|").split("|")]
           for l in section.splitlines() if l.strip().startswith("|")]
    return out[0] if out else [], out[2:]


def stage_agents():
    """Names of HQ's stage agents: the Agent column of the `Stage | Agent` table in
    .claude/agents/README.md."""
    f = Path(HQ) / ".claude" / "agents" / "README.md"
    text = f.read_text(encoding="utf-8") if f.is_file() else ""
    for block in re.split(r"\n\s*\n", text):
        head, rows = _rows(block)
        if head == ["Stage", "Agent"]:
            return {r[1][:-3] if r[1].endswith(".md") else r[1] for r in rows if len(r) > 1}
    return set()


def _sections(text):
    return {m.group(1).strip(): m.group(2)
            for m in re.finditer(r"^## (.+?)[ \t]*\n(.*?)(?=^## |\Z)", text, re.S | re.M)}


HEADERS = {
    "Trigger": ["Kind", "Value"],
    "Inputs": ["Input", "Required", "Default", "Meaning"],
    "Stages": ["Stage", "Kind", "Agent", "Ask"],
    "Arrows": ["From", "Outcome", "To"],
    "Items": ["Made by", "Starts at"],
}


def parse_workflow(name, text):
    """A workflow file as {name, purpose, triggers, inputs, stages, can_start, error}.
    `error` is a non-empty reason when the file can't run; the rest is filled as far as it reads."""
    w = {"id": name, "name": name, "purpose": "", "triggers": [], "inputs": [], "stages": [],
         "can_start": False, "error": ""}
    m = re.search(r"^# .+\n+([^\n#|][^\n]*)", text, re.M)
    if m:
        w["purpose"] = m.group(1).strip()
    secs = _sections(text)
    problems = []
    parsed = {}
    for sec, want in HEADERS.items():
        if sec not in secs:
            if sec != "Inputs":
                problems.append(f"no ## {sec} section")
            continue
        header, rows = _rows(secs[sec])
        if header != want:
            problems.append(f"## {sec} columns must be {' | '.join(want)}")
        elif any(len(r) != len(want) for r in rows):
            bad = next(r for r in rows if len(r) != len(want))
            problems.append(f"## {sec} row has {len(bad)} cells, want {len(want)}: {'|'.join(bad)}")
        else:
            parsed[sec] = rows
            if not rows and sec != "Inputs":
                problems.append(f"## {sec} is empty")
    w["triggers"] = [{"kind": r[0], "value": r[1]} for r in parsed.get("Trigger", [])]
    w["inputs"] = [{"name": r[0], "required": r[1].lower() == "yes", "default": r[2], "meaning": r[3]}
                   for r in parsed.get("Inputs", [])]
    w["stages"] = [{"stage": r[0], "kind": r[1], "agent": r[2], "ask": r[3]} for r in parsed.get("Stages", [])]
    if "Items" in parsed and not any(r[0] == "trigger" for r in parsed["Items"]):
        problems.append("## Items has no row made by trigger")
    w["error"] = "; ".join(problems)
    w["can_start"] = not w["error"] and any(t["kind"] == "run" for t in w["triggers"])
    return w


def workflows(full, hq_full, run):
    files = _files(full, hq_full, "workflows", run)
    return [parse_workflow(n, files[n]) for n in sorted(files)]


def workflow(full, hq_full, name, run):
    return next((w for w in workflows(full, hq_full, run) if w["id"] == name), None)
