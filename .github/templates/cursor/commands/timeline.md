---
id: timeline
version: 4.0
created: 2025-11-26
updated: 2026-03-11
category: data-operations
layer: 1
type: tool/basic

chains_with: []
depends_on:
  - "date: current timestamp"
  - "jq: read/write JSON"
  - "git (optional): resolve repo root"
used_by: []
usage_stats:
  invocations: 0

operation: APPEND-ONLY
---

# timeline

**Definition / promise:** Append-only **project memory** — a timestamped ledger and makeshift database for full traceability and auditability. AI agents extend `timeline.json` (or `*.timeline.json`) as you work, or you invoke explicitly (e.g. `/timeline` or "update timeline"). **Why:** Context persists across sessions; when you return to a project, agents (or you) read the timeline to understand what happened, what decisions were made, and what's blocked.

Operationally: locate existing `timeline.json` or `*.timeline.json` at workspace/git root, compute delta from last entry vs current session, append 1..n granular entries. No create; no org-specific logic.

## Schema

### Command operation

```json
{
  "$schema": "http://json-schema.org/draft-2020-12/schema#",
  "type": "object",
  "description": "Timeline command operation and entry shape (infer exact schema from target file)",
  "properties": {
    "target_file": { "type": "string", "pattern": "^(timeline\\.json|.+\\.timeline\\.json)$", "description": "Exactly timeline.json or <name>.timeline.json only; reject e.g. mytimeline.json" },
    "ts": { "type": "string", "format": "date-time", "description": "ISO8601 from date -u +%Y-%m-%dT%H:%M:%SZ" },
    "entry": {
      "type": "object",
      "properties": {
        "id": { "type": "string", "description": "Unique identifier (e.g. UUID); mandatory for file entry" },
        "uuid": { "type": "string", "description": "Alias for id" },
        "ts": { "type": "string", "format": "date-time" },
        "type": { "type": "string", "enum": ["milestone", "note", "decision", "blocker", "resolution", "investigation", "cleanup", "infra", "summary", "start"] },
        "content": { "type": "string" },
        "note": { "type": "string" },
        "context": { "type": "object", "additionalProperties": true },
        "operation": { "type": "string" }
      },
      "required": ["ts", "type"],
      "additionalProperties": true
    },
    "entries_added": { "type": "integer", "minimum": 0, "description": "Count of new entries appended" }
  },
  "required": ["target_file", "ts"]
}
```

### timeline.json (file) schema

**Flexible schema:** only a small set of fields are mandatory; all others are optional and may be dropped, added, or extended at any time. Infer from the existing file; new entries must include the mandatory fields and may include any predicted or custom fields.

- **Mandatory (fixed):** file must have `entries` (array). Each entry must have a unique **identifier** (`id` or `uuid`).
- **Predicted optional (entry):** `ts`, `type`, `content`, `note`, `context`, `operation` — use if present in the file; omit or add others as needed.
- **Predicted optional (top-level):** `meta`, `status`, `goal`, `last_updated`, `decisions`, `blockers`, `learnings` — same rule.
- **Extension:** any field may be dropped, added, or new keys included; `additionalProperties: true` everywhere. Only mandatory fields are enforced.

```json
{
  "$schema": "http://json-schema.org/draft-2020-12/schema#",
  "$id": "https://gh-template/timeline.json/schema",
  "title": "timeline.json",
  "description": "Append-only event ledger; flexible schema. Mandatory: entries[], entry.id. All other fields optional; add/drop/extend as needed.",
  "type": "object",
  "required": ["entries"],
  "properties": {
    "entries": {
      "type": "array",
      "description": "Append-only list of events; never modify or delete existing items",
      "items": { "$ref": "#/$defs/entry" }
    },
    "meta": { "type": "object", "additionalProperties": true },
    "status": { "type": "string" },
    "goal": {},
    "last_updated": { "type": "string", "format": "date-time" },
    "decisions": { "type": "array" },
    "blockers": { "type": "array" },
    "learnings": { "type": "array" }
  },
  "additionalProperties": true,
  "$defs": {
    "entry": {
      "type": "object",
      "description": "One event. Mandatory: id (or uuid). All other fields optional; add/drop/extend as needed.",
      "properties": {
        "id": { "type": "string", "description": "Unique identifier (e.g. UUID); mandatory" },
        "uuid": { "type": "string", "description": "Alias for id; use id or uuid per file convention" },
        "ts": { "type": "string", "format": "date-time" },
        "type": { "type": "string" },
        "content": { "type": "string" },
        "note": { "type": "string" },
        "context": { "type": "object", "additionalProperties": true },
        "operation": { "type": "string" }
      },
      "required": [],
      "oneOf": [
        { "required": ["id"] },
        { "required": ["uuid"] }
      ],
      "additionalProperties": true
    }
  }
}
```

When appending: generate a new identifier for each entry (e.g. UUID or unique string). Preserve existing field set from the file; only add mandatory `id`/`uuid` if the file's entries already use it. Existing entries in the file may lack `id`/`uuid`; the command only enforces an identifier on newly appended entries.

## Execution Rules

```yaml
logic:
  resolve_root: "workspace root or git root from {recent_context}; do not search up from cwd"
  locate: "at root accept only timeline.json or <name>.timeline.json (one dot before 'timeline'); reject names like mytimeline.json; if none, stop"
  read: "last entry in entries[] + top-level metadata/schema"
  timestamp: "date -u +%Y-%m-%dT%H:%M:%SZ"
  delta: "compare last entry to current chat session (as far back as recall); identify changes, decisions, blockers, milestones"
  granularity: "entries_added = f(amount of change + context updates); not f(time since last entry)"
  append: "push 1..n entries to entries[]; conform to existing schema; optionally set last_updated"

validation:
  - "target_file is exactly timeline.json OR <name>.timeline.json (dot required before 'timeline'); reject mytimeline.json and similar"
  - "target_file exists and is writable"
  - "never modify or delete existing entries"
  - "new entries include identifier (id or uuid); match other fields to schema inferred from existing entries and top-level keys"

enforcement:
  - "APPEND-ONLY"
  - "Single file at root only"
  - "No creation of timeline file"
  - "Agnostic: no org-specific or proprietary fields"
```

## Implementation

```yaml
script: "agent-driven (no binary); uses date, jq, optional git"
usage: "implicit (agent) or explicit ('update timeline' / 'append to timeline')"
output: "updated timeline.json or *.timeline.json with new entries; preserve meta, goal, decisions, blockers, etc."
steps:
  - "resolve workspace/git root"
  - "find timeline.json or <name>.timeline.json at root only (reject mytimeline.json-style names); exit if missing"
  - "read file; infer schema from entries and top-level keys"
  - "compute delta (session vs last entry); decide N entries"
  - "for each entry: generate id (e.g. UUID); ts from date; type; content or note; optional context/operation; preserve or add fields per file convention"
  - "append to entries[]; write back; set last_updated if present"
```

## Quick Reference

| Intent | Action |
|--------|--------|
| Update timeline | Compute delta, append to timeline.json or <name>.timeline.json at root (not mytimeline.json) |
| Entry shape | id or uuid (mandatory), ts, type, content|note, optional context/operation; flexible — add/drop fields per file |
