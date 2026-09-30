"""What a page can do: its agents, skills and workflows (HQ's plus the domain's own, the
domain's winning on a name clash), read from files — HQ's from this checkout, a domain's
from GitHub. A skill with `hq-only: true` in its frontmatter stays on HQ's page. Formats:
.claude/agents/README.md (agent cards, skills), orchestration/workflows.md."""
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


def _local_skills():
    d = Path(HQ) / ".claude" / "skills"
    return [(f.parent.name, f.read_text(encoding="utf-8")) for f in sorted(d.glob("*/SKILL.md"))] if d.is_dir() else []


def _remote_skills(full, run):
    """(folder, SKILL.md text) of each skill folder of repo `full`; [] if there is no skills folder."""
    listing, _ = ghcache.fetch(f"repos/{full}/contents/.claude/skills", run, missing_ok=True)
    out = []
    for f in listing or []:
        if f.get("type") != "dir":
            continue
        body, _ = ghcache.fetch(f"repos/{full}/contents/.claude/skills/{f['name']}/SKILL.md", run, missing_ok=True)
        if body and body.get("content") is not None:
            out.append((f["name"], base64.b64decode(body["content"]).decode("utf-8", "replace")))
    return out


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
    """Cards for the agents of page `full`, sorted by id."""
    files = _files(full, hq_full, ".claude/agents", run)
    return [_card(stem, files[stem]) for stem in sorted(files)]


def skills(full, hq_full, run):
    """Skills of page `full`, sorted by name: HQ's (minus `hq-only: true` ones on a domain page),
    then the domain's own over them; `replaces` marks one that displaces an HQ skill."""
    hq = dict(_local_skills())
    found = {k: t for k, t in hq.items()
             if full == hq_full or agent_cards.frontmatter(t).get("hq-only", "").lower() != "true"}
    own = {}
    if full != hq_full:
        own = dict(_remote_skills(full, run))
        found.update(own)
    out = []
    for k in sorted(found):
        fm = agent_cards.frontmatter(found[k])
        out.append({"id": k, "name": fm.get("name") or k, "description": fm.get("description") or "",
                    "file": f".claude/skills/{k}/SKILL.md", "replaces": k in own and k in hq,
                    "hq_only": fm.get("hq-only", "").lower() == "true"})
    return out


def _rows(section):
    out = [[c.strip().replace("`", "") for c in l.strip().strip("|").split("|")]
           for l in section.splitlines() if l.strip().startswith("|")]
    return out[0] if out else [], out[2:]


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
