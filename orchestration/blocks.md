# Result blocks

How an agent writes a result on an Issue so the dashboard (`/v2`) can draw it. Use blocks
where they fit; write ordinary Markdown everywhere else.

## Format

A block is a fenced code block. The opening line is exactly ` ```hq-block ` and the closing
line is exactly ` ``` `, both at column 0. The body is **one JSON object** with a `"type"`
field. GitHub shows it as a plain code block, so nothing is hidden there.

Rules:

- Strings use `"double quotes"`. Keep quotes and backslashes out of values — they need
  escaping in JSON.
- URLs must start with `https://` or `http://`.
- A block is **malformed** if: the JSON is invalid; the body isn't an object; `type` is
  unknown; a required field is missing; a field has the wrong type; a field isn't listed
  here; a URL isn't http(s); the closing fence is missing.
- A malformed block is shown as the plain text you wrote. Nothing else on the page breaks.

**Mixing:** a comment can hold any number of blocks between ordinary Markdown. Text outside
blocks is shown exactly as written.

## Which block

| Block | Use it for |
|---|---|
| text | A short paragraph that needs no other block |
| stat | One number that matters (one), or a few side by side (row) |
| table | Many items, each with the same fields |
| list | Ideas, options, notes — bullets, or numbered when order matters. Not pass/fail |
| chart | Comparing numbers: bar for categories, line for change over a sequence |
| file | Pointing at one file or artifact, with a note |
| change | A code change to show, as a diff |
| callout | Something the reader must not miss: a warning or an important note |
| key-value | Facts about **one** thing (table is for **many** things) |
| checks | Pass/fail results, one per check (list is for ideas, checks for pass/fail) |
| steps | Progress through ordered work: done, doing, to do |
| image | A picture, with alt text |
| source | A quote and where it came from |

## Blocks

Each field table: `field | required? | type | meaning`.

### text

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"text"` | |
| `text` | yes | string | The paragraph |

```hq-block
{"type": "text", "text": "The runner now retries a failed push once."}
```

### stat — one

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"stat"` | |
| `label` | yes | string | What is measured |
| `value` | yes | number | The figure |
| `unit` | no | string | Shown after the value |
| `note` | no | string | One line of context |

```hq-block
{"type": "stat", "label": "Tests passed", "value": 42, "unit": "of 45", "note": "3 skipped"}
```

### stat — row

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"stat"` | |
| `items` | yes | list of objects | Each has `label` (string, required), `value` (number, required), `unit` (string, optional) |

```hq-block
{"type": "stat", "items": [{"label": "Files changed", "value": 4}, {"label": "Lines added", "value": 120}, {"label": "Runtime", "value": 3.5, "unit": "s"}]}
```

### table

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"table"` | |
| `columns` | yes | list of strings | Column headings |
| `rows` | yes | list of lists | Each row as long as `columns`; cells are strings or numbers |
| `title` | no | string | Heading above the table |

```hq-block
{"type": "table", "title": "Routes", "columns": ["Path", "Status"], "rows": [["/v2", "ok"], ["/api/review", "ok"], ["/old", 404]]}
```

### list — bullets

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"list"` | |
| `items` | yes | list of strings | One per bullet |
| `numbered` | no | bool | `false` (default) gives bullets |

```hq-block
{"type": "list", "items": ["Cache the digest", "Batch the label calls", "Drop the retry"]}
```

### list — numbered

Same fields as bullets, with `"numbered": true`.

```hq-block
{"type": "list", "numbered": true, "items": ["Open the page", "Click Approve", "Confirm the merge"]}
```

### chart — bar

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"chart"` | |
| `kind` | yes | `"bar"` or `"line"` | |
| `labels` | yes | list of strings | One per data point, at least one |
| `values` | yes | list of numbers ≥ 0 | Same length as `labels` |
| `title` | no | string | Heading above the chart |
| `unit` | no | string | Shown after each value |

```hq-block
{"type": "chart", "kind": "bar", "title": "Runs per stage", "labels": ["Plan", "Build", "QA"], "values": [3, 5, 2], "unit": "runs"}
```

### chart — line

Same fields as bar, with `"kind": "line"`.

```hq-block
{"type": "chart", "kind": "line", "title": "Open Work Items", "labels": ["Mon", "Tue", "Wed", "Thu"], "values": [4, 6, 5, 8]}
```

### file

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"file"` | |
| `path` | yes | string | File path or name |
| `url` | no | string | Link to the file (http/https) |
| `note` | no | string | What it is |

```hq-block
{"type": "file", "path": "orchestration/blocks.md", "url": "https://github.com/Logangosha/hq/blob/main/orchestration/blocks.md", "note": "The result format"}
```

### change

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"change"` | |
| `file` | yes | string | File changed |
| `diff` | yes | string | Unified-diff lines, joined with `\n` |
| `note` | no | string | What changed and why |

```hq-block
{"type": "change", "file": "scripts/notify.sh", "diff": "@@ -1,2 +1,2 @@\n-echo old\n+echo new\n done", "note": "Message reworded"}
```

### callout

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"callout"` | |
| `text` | yes | string | The message |
| `title` | no | string | Bold heading |
| `tone` | no | `"info"` or `"warning"` | Default `info` |

```hq-block
{"type": "callout", "tone": "warning", "title": "Runner change", "text": "This only takes effect on the next run from main."}
```

### key-value

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"key-value"` | |
| `items` | yes | list of objects | Each has `key` (string, required) and `value` (string or number, required) |

```hq-block
{"type": "key-value", "items": [{"key": "Repo", "value": "Logangosha/hq"}, {"key": "PR", "value": 216}, {"key": "Branch", "value": "work-item-212"}]}
```

### checks

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"checks"` | |
| `items` | yes | list of objects | Each has `name` (string, required), `pass` (bool, required), `note` (string, optional) |

```hq-block
{"type": "checks", "items": [{"name": "V1 doc exists", "pass": true}, {"name": "V2 fields listed", "pass": false, "note": "chart has no unit"}]}
```

### steps

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"steps"` | |
| `items` | yes | list of objects | Each has `name` (string, required) and `state` (`"done"`, `"doing"` or `"todo"`, required) |

```hq-block
{"type": "steps", "items": [{"name": "Write the doc", "state": "done"}, {"name": "Draw the blocks", "state": "doing"}, {"name": "Check it", "state": "todo"}]}
```

### image

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"image"` | |
| `url` | yes | string | Image address (http/https) |
| `alt` | yes | string | What the image shows |
| `caption` | no | string | Shown under the image |

```hq-block
{"type": "image", "url": "https://example.com/review.png", "alt": "The Review page", "caption": "Review page in dark mode"}
```

### source

| Field | Required | Type | Meaning |
|---|---|---|---|
| `type` | yes | `"source"` | |
| `quote` | yes | string | The quoted words |
| `from` | yes | string | Where it came from |
| `url` | no | string | Link to the source (http/https) |

```hq-block
{"type": "source", "quote": "Done means proven.", "from": "HQ CLAUDE.md, core rule 2", "url": "https://example.com/claude-md"}
```
