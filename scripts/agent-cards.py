#!/usr/bin/env python3
"""Print every agent's self-description (its `## Card`) as JSON.

Usage: agent-cards.py <dir or .md file>...
A dir means its *.md files except README.md. Format: .claude/agents/README.md.
Exit 0 if all cards are fine, 1 if any is malformed (JSON is still printed in full),
2 on a bad path or usage.
"""
import json
import re
import sys
from pathlib import Path

FIELDS = {"Name", "Icon", "Purpose", "Inputs", "Output"}
KINDS = {"question", "log", "job"}
INPUTS = {"text", "files", "text, files", "none"}
SHORTCUT_COLS = ["Label", "Kind", "Ask", "Needs"]


def frontmatter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    out = {}
    for line in (m.group(1).splitlines() if m else []):
        k, sep, v = line.partition(":")
        if sep:
            out[k.strip()] = v.strip()
    return out


def rows(lines):
    """Table rows as lists of cells, header and separator dropped."""
    out = [[c.strip() for c in l.strip().strip("|").split("|")]
           for l in lines if l.strip().startswith("|")]
    return out[2:]


def card_section(text):
    m = re.search(r"^## Card[ \t]*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    return m.group(1) if m else None


def parse(path):
    text = path.read_text()
    fm = frontmatter(text)
    name = fm.get("name") or path.stem
    entry = {"file": str(path), "name": name, "display_name": name,
             "icon": None, "purpose": fm.get("description"), "inputs": None,
             "output": None, "shortcuts": [], "fallback": False, "errors": []}
    err = lambda f, p: entry["errors"].append({"field": f, "problem": p})
    card = card_section(text)
    if card is None:
        entry["fallback"] = True
        return entry
    main, _, short = card.partition("### Shortcuts")
    values = {}
    for r in rows(main.splitlines()):
        if len(r) != 2:
            err("Card", f"row has {len(r)} cells, want 2: {'|'.join(r)}")
        elif r[0] not in FIELDS:
            err(r[0], "unknown field")
        else:
            values[r[0]] = r[1]
    for f in sorted(FIELDS):
        if not values.get(f):
            err(f, "missing or empty")
    if values.get("Name"):
        entry["display_name"] = values["Name"]
    if values.get("Purpose"):
        entry["purpose"] = values["Purpose"]
    if values.get("Output"):
        entry["output"] = values["Output"]
    icon = values.get("Icon")
    if icon:
        if re.fullmatch(r"[a-z0-9_]+", icon):
            entry["icon"] = icon
        else:
            err("Icon", f"not a Material Symbols name: {icon}")
    inp = values.get("Inputs")
    if inp:
        if inp in INPUTS:
            entry["inputs"] = [] if inp == "none" else inp.split(", ")
        else:
            err("Inputs", f"must be one of {sorted(INPUTS)}, got: {inp}")
    if short:
        lines = short.splitlines()
        header = [c.strip() for c in next((l for l in lines if l.strip().startswith("|")), "").strip().strip("|").split("|")]
        if header != SHORTCUT_COLS:
            err("Shortcuts", f"columns must be {' | '.join(SHORTCUT_COLS)}")
        else:
            for r in rows(lines):
                if len(r) != 4:
                    err("Shortcuts", f"row has {len(r)} cells, want 4: {'|'.join(r)}")
                    continue
                label, kind, ask, needs = r
                if not label:
                    err("Shortcuts.Label", "empty")
                if kind not in KINDS:
                    err("Shortcuts.Kind", f"must be question, log or job, got: {kind}")
                if not ask:
                    err("Shortcuts.Ask", f"empty (shortcut: {label})")
                entry["shortcuts"].append({"label": label, "kind": kind, "ask": ask, "needs": needs or None})
    return entry


def main(args):
    if not args:
        print(__doc__, file=sys.stderr)
        return 2
    files = []
    for a in args:
        p = Path(a)
        if p.is_dir():
            files += sorted(f for f in p.glob("*.md") if f.name != "README.md")
        elif p.is_file():
            files.append(p)
        else:
            print(f"agent-cards.py: no such file or directory: {a}", file=sys.stderr)
            return 2
    entries = [parse(f) for f in files]
    bad = False
    for e in entries:
        for x in e["errors"]:
            bad = True
            print(f"{e['file']}: {x['field']}: {x['problem']}", file=sys.stderr)
    json.dump(entries, sys.stdout, indent=2)
    print()
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
