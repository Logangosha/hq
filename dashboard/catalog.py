"""What a page can do: its agents, skills and workflows (HQ's plus the domain's own, the
domain's winning on a name clash) and its triggers (the repo's own `triggers/`, never HQ's
on a domain page), read from files — HQ's from this checkout, a domain's
from GitHub. HQ's stage agents are left out on every page; on a domain page HQ's general ones carry
`general`. A skill shows only with a valid `## Card`; one with `hq-only: true` in its
frontmatter stays on HQ's page; `disable-model-invocation: true` makes it user-only
(`user_only`). Every card carries `product`, `uses`, `started_by` and `view_only`
(orchestration/contract.md). An agent card carries `can_use` (its listed skills and workflows) and
`access_errors` (a listed user-only skill). Formats: .claude/agents/README.md (agent cards,
skills), orchestration/workflows.md, triggers: orchestration/contract.md."""
import base64
import importlib.util
import os
import re
import subprocess
import tempfile
from pathlib import Path

import ghcache

HQ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("agent_cards", os.path.join(HQ, "scripts", "agent-cards.py"))
agent_cards = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(agent_cards)

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
# The Work Item lifecycle workflows: always view only (scripts/runner/flow-lib.sh).
WORK_ITEM_NAMES = ("work-item", "small-work-item")


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


def _parse(stem, text, kind="agent"):
    with tempfile.TemporaryDirectory() as tmp:
        p = Path(tmp) / f"{stem}.md"
        p.write_text(text, encoding="utf-8")
        return agent_cards.parse(p, kind)


def _card(stem, text):
    e = _parse(stem, text)
    e["id"] = stem
    e["file"] = f".claude/agents/{stem}.md"
    e["description"] = agent_cards.frontmatter(text).get("description") or ""
    if e["errors"] or e["fallback"]:
        # A missing or malformed card falls back whole: name and description only.
        e.update(display_name=e["name"], icon="smart_toy", inputs=None, product=None,
                 started_by=["user"], view_only=False, shortcuts=[])
        e["purpose"] = agent_cards.frontmatter(text).get("description") or ""
    return e


def _listed(text, field):
    """Names in an agent's `skills:` / `workflows:` frontmatter line, in order."""
    names = [n.strip() for n in agent_cards.frontmatter(text).get(field, "").split(",")]
    return [n for n in names if NAME_RE.match(n)]


def _with_access(access, text, card):
    """Adds `can_use` and `access_errors` to an agent card."""
    sk, wf, names = access
    card["can_use"] = {"skills": [{"id": k, "name": names.get(k, k)} for k in _listed(text, "skills")],
                       "workflows": [{"id": k, "name": wf.get(k, k)} for k in _listed(text, "workflows")]}
    card["access_errors"] = [f"Lists user-only skill {k}; agents can't use it."
                             for k in _listed(text, "skills") if k in sk and _user_only(sk[k])]
    return card


def agents(full, hq_full, run):
    """Cards for the agents of page `full`, sorted by id. HQ's stage agents are left
    out on every page; on a domain's page HQ's general ones are marked `general` (the domain's own win)."""
    sk = _skill_texts(full, hq_full, run)
    names = {}
    for k, t in sk.items():
        c = _parse(k, t)
        if not c["fallback"] and not c["errors"]:
            names[k] = c["display_name"]
    access = (sk, {w["id"]: w["name"] for w in workflows(full, hq_full, run)}, names)

    def card(stem, text, **extra):
        return _with_access(access, text, dict(_card(stem, text), **extra))
    stage = stage_agents()
    if full == hq_full:
        files = _files(full, hq_full, ".claude/agents", run)
        return [card(stem, files[stem]) for stem in sorted(files) if stem not in stage]
    cards = {s: card(s, t, general=True) for s, t in _local(".claude/agents") if s not in stage}
    cards.update({s: card(s, t) for s, t in _remote(full, ".claude/agents", run)})
    return [cards[s] for s in sorted(cards)]


def _user_only(text):
    return agent_cards.frontmatter(text).get("disable-model-invocation", "").lower() == "true"


def _skill_texts(full, hq_full, run):
    """Every skill SKILL.md of page `full`, carded or not: HQ's (minus `hq-only: true` ones
    on a domain page), then the domain's own over them. Returns (id -> text)."""
    return _skill_merge(full, hq_full, run)[0]


def _skill_merge(full, hq_full, run):
    hq = dict(_local_skills())
    found = {}
    for k, t in hq.items():
        if full == hq_full or agent_cards.frontmatter(t).get("hq-only", "").lower() != "true":
            found[k] = t
    own = {}
    if full != hq_full:
        own = dict(_remote_skills(full, run))
        found.update(own)
    return found, own, hq


def skills(full, hq_full, run):
    """Skills of page `full`, sorted by name: HQ's (minus `hq-only: true` ones on a domain
    page), then the domain's own over them; `replaces` marks one that displaces an HQ skill.
    Only skills with a valid `## Card` are listed, so a card-less domain skill hides the HQ
    skill it replaces too."""
    found, own, hq = _skill_merge(full, hq_full, run)
    out = []
    for k in sorted(found):
        card = _parse(k, found[k], "skill")
        if card["fallback"] or any(not e["field"].startswith("Shortcuts") for e in card["errors"]):
            continue  # no card, or a malformed one; a Shortcuts table is ignored
        fm = agent_cards.frontmatter(found[k])
        out.append({"id": k, "name": fm.get("name") or k, "description": fm.get("description") or "",
                    "file": f".claude/skills/{k}/SKILL.md", "replaces": k in own and k in hq,
                    "hq_only": fm.get("hq-only", "").lower() == "true",
                    "user_only": _user_only(found[k]),
                    "display_name": card["display_name"], "icon": card["icon"],
                    "purpose": card["purpose"], "inputs": card["inputs"],
                    "hint": card["hint"], "product": card["product"], "uses": card["uses"],
                    "started_by": card["started_by"], "view_only": card["view_only"]})
    return out


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
    "Inputs": ["Input", "Required", "Default", "Meaning"],
    "Stages": ["Stage", "Kind", "Agent", "Ask"],
    "Arrows": ["From", "Outcome", "To"],
    "Items": ["Made by", "Starts at"],
}


def parse_workflow(name, text):
    """A workflow file as {name, purpose, triggers, inputs, stages, can_start, view_only, error}.
    `name` is the `# ` heading. `view_only` (Started by without `user`) means drawn only: never
    startable by hand. `triggers` and `can_start` are filled by `workflows()`; Start needs no
    trigger file. `error` is a non-empty reason when the file can't run; the rest is filled
    as far as it reads."""
    w = {"id": name, "name": name, "purpose": "", "triggers": [], "inputs": [], "stages": [],
         "can_start": False, "view_only": False, "error": "",
         "product": None, "uses": [], "started_by": ["user"]}
    h = re.search(r"^# (.+?)[ \t]*$", text, re.M)
    if h:
        w["name"] = h.group(1)
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
    w["inputs"] = [{"name": r[0], "required": r[1].lower() == "yes", "default": r[2], "meaning": r[3]}
                   for r in parsed.get("Inputs", [])]
    w["stages"] = [{"stage": r[0], "kind": r[1], "agent": r[2], "ask": r[3]} for r in parsed.get("Stages", [])]
    if "Items" in parsed and not any(r[0] == "trigger" for r in parsed["Items"]):
        problems.append("## Items has no row made by trigger")
    if "Card" in secs:
        header, rows = _rows(secs["Card"])
        vals = {}
        for r in rows:
            if len(r) != 2:
                problems.append(f"## Card row has {len(r)} cells, want 2: {'|'.join(r)}")
            elif r[0] not in ("Product", "Uses", "Started by"):
                problems.append(f"## Card: unknown field {r[0]}")
            else:
                vals[r[0]] = r[1]
        w["product"] = vals.get("Product") or None
        if "Uses" in vals:
            w["uses"], bad = agent_cards.uses(vals["Uses"])
            if bad:
                problems.append(f"## Card Uses: {bad}")
                w["uses"] = []
        if "Started by" in vals:
            w["started_by"], bad = agent_cards.started_by(vals["Started by"])
            if bad:
                problems.append(f"## Card Started by: {bad}")
                w["started_by"] = ["user"]
    seen = {f"agent:{x['agent']}" for x in w["stages"] if x["kind"] == "agent"}
    w["uses"] += sorted(seen - set(w["uses"]))
    w["error"] = "; ".join(problems)
    w["view_only"] = "user" not in w["started_by"]
    return w


def _read_trigger(name, text):
    """Default reader: the one bash parser the scheduler uses too (scripts/runner/trigger-read.sh).
    The server may replace this to run it through its own bash."""
    res = subprocess.run(["bash", str(Path(HQ) / "scripts" / "runner" / "trigger-read.sh"), name],
                         input=text, capture_output=True, text=True, cwd=HQ)
    return res.stdout


read_trigger = _read_trigger


def _trigger_rows(full, hq_full, run):
    """The repo's own trigger files, parsed: {id, name, kind, target, when, ask, error}.
    A domain page never shows HQ's; HQ's page shows HQ's own."""
    files = _local("triggers") if full == hq_full else _remote(full, "triggers", run)
    out = []
    for name, text in files:
        f = {}
        for line in read_trigger(name, text).splitlines():
            k, _, v = line.partition("=")
            f[k] = v
        kind = f.get("kind", "")
        err = f.get("error") if "error" in f else "trigger file could not be read"
        out.append({"id": name, "name": name, "kind": kind, "target": f.get("target", ""),
                    "when": f.get("when", ""),
                    "cron": f.get("when", "") if kind == "schedule" else "",
                    "ask": f.get("ask", ""), "error": err or ""})
    return out


def triggers(full, hq_full, run):
    """The page's triggers, one row each. Besides the file's own problems, a target that doesn't
    exist here, or a schedule whose target's Started by lacks `schedule`, is an error (the
    scheduler refuses the same)."""
    rows = _trigger_rows(full, hq_full, run)
    if not any(not r["error"] for r in rows):
        return rows
    skill_ids = set(_skill_texts(full, hq_full, run))
    skill_cards = {s["id"]: s for s in skills(full, hq_full, run)}
    agent_cards_ = {a["id"]: a for a in agents(full, hq_full, run)}
    wf_cards = {w["id"]: w for w in workflows(full, hq_full, run)}
    for r in rows:
        if r["error"]:
            continue
        kind, _, name = r["target"].partition(":")
        card = {"skill": skill_cards.get(name), "agent": agent_cards_.get(name),
                "workflow": wf_cards.get(name)}[kind]
        exists = name in skill_ids if kind == "skill" else card is not None
        if not exists:
            r["error"] = f"no such {kind} {name} here"
        elif r["kind"] == "schedule" and "schedule" not in (card["started_by"] if card else ["user"]):
            r["error"] = f"{r['target']} isn't started by schedule"
        elif r["kind"] == "event" and "event" not in (card["started_by"] if card else ["user"]):
            r["error"] = f"{r['target']} isn't started by event"
    return rows


def workflows(full, hq_full, run):
    files = _files(full, hq_full, "workflows", run)
    rows = _trigger_rows(full, hq_full, run)
    out = []
    for n in sorted(files):
        w = parse_workflow(n, files[n])
        w["triggers"] = [{"kind": t["kind"], "value": t["when"] or t["target"], "name": t["name"],
                          "error": t["error"]}
                         for t in rows if t["target"] == f"workflow:{n}"]
        w["can_start"] = not w["error"] and not w["view_only"] and n not in WORK_ITEM_NAMES
        w["view_only"] = w["view_only"] or n in WORK_ITEM_NAMES
        out.append(w)
    return out


def workflow(full, hq_full, name, run):
    return next((w for w in workflows(full, hq_full, run) if w["id"] == name), None)
