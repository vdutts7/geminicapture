---
id: add-social-badges
version: 1.0
created: 2026-03-11
category: workflow
layer: 2
type: tool/basic

chains_with: []
depends_on: []
used_by: []
usage_stats:
  invocations: 0
---

# add-social-badges

Insert the vd7.io + /vdutts7 pill badge unit at a user-specified location (file and/or section). Badges are **hardcoded as data URIs** in this command; no repo assets or external links required.

## Schema

```json
{
  "$schema": "http://json-schema.org/draft-2020-12/schema#",
  "type": "object",
  "properties": {
    "target_file": { "type": "string", "description": "Path to file to modify (default: current or user-specified)" },
    "insert_after": { "type": "string", "description": "Optional anchor line after which to insert (e.g. '## Contact')" },
    "insert_at_end": { "type": "boolean", "description": "If true, append at end of file when no anchor" }
  }
}
```

## Execution Rules

```yaml
logic:
  - "Resolve target file from user (e.g. README.md, or current open file)"
  - "Resolve insertion point: after insert_after line, or end of file, or user says 'under Contact'"
  - "Insert badge_block (exactly once) at that location; add newline before/after if needed"

validation:
  - "Do not duplicate the badge block if it already exists at/near the insertion point"

enforcement:
  - "Badge block is exactly the two-line HTML unit below; do not alter URLs or styles"
```

## Badge block (insert this)

Badges are **hardcoded as data URIs** (no repo assets or external links). Insert this exact block:

```html
<a href="https://vd7.io"><img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI5NyIgaGVpZ2h0PSI0MCIgdmlld0JveD0iMCAwIDk3IDQwIj48ZGVmcz48bGluZWFyR3JhZGllbnQgaWQ9ImNpcmNsZSIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMCUiPjxzdG9wIG9mZnNldD0iMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiM1ZGQzZmYiLz48c3RvcCBvZmZzZXQ9IjEwMCUiIHN0eWxlPSJzdG9wLWNvbG9yOiMyMmE4YzkiLz48L2xpbmVhckdyYWRpZW50PjwvZGVmcz48cmVjdCB4PSIwIiB5PSIwIiB3aWR0aD0iOTciIGhlaWdodD0iNDAiIHJ4PSIyMCIgcnk9IjIwIiBmaWxsPSIjMDAwIiBzdHJva2U9InJnYmEoMjU1LDI1NSwyNTUsMC4yKSIgc3Ryb2tlLXdpZHRoPSIxIi8+PGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTMsIDApIj48Y2lyY2xlIGN4PSI5IiBjeT0iMjAiIHI9IjkiIGZpbGw9InVybCgjY2lyY2xlKSIvPjx0ZXh0IHg9IjI2IiB5PSIyNSIgZmlsbD0iI2ZmZiIgZm9udC1mYW1pbHk9IidKZXRCcmFpbnMgTW9ubycsJ1NGIE1vbm8nLCdGaXJhIENvZGUnLG1vbm9zcGFjZSIgZm9udC1zaXplPSIxMyIgZm9udC13ZWlnaHQ9IjUwMCI+dmQ3LmlvPC90ZXh0PjwvZz48L3N2Zz4=" alt="vd7.io" height="40" /></a> &nbsp; <a href="https://x.com/vdutts7"><img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMTgiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCAxMTggNDAiPjxyZWN0IHg9IjAiIHk9IjAiIHdpZHRoPSIxMTgiIGhlaWdodD0iNDAiIHJ4PSIyMCIgcnk9IjIwIiBmaWxsPSIjMDAwIiBzdHJva2U9InJnYmEoMjU1LDI1NSwyNTUsMC4yKSIgc3Ryb2tlLXdpZHRoPSIxIi8+PGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMTMsIDApIj48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSg5LCAyMCkgc2NhbGUoMC41NSkgdHJhbnNsYXRlKC0xMiwgLTEyKSI+PHBhdGggZD0iTTE4LjI0NCAyLjI1aDMuMzA4bC03LjIyNyA4LjI2IDguNTAyIDExLjI0SDE2LjE3bC01LjIxNC02LjgxN0w0Ljk5IDIxLjc1SDEuNjhsNy43My04LjgzNUwxLjI1NCAyLjI1SDguMDhsNC43MTMgNi4yMzF6bS0xLjE2MSAxNy41MmgxLjgzM0w3LjA4NCA0LjEyNkg1LjExN3oiIGZpbGw9IiNmZmYiLz48L2c+PHRleHQgeD0iMjYiIHk9IjI1IiBmaWxsPSIjZmZmIiBmb250LWZhbWlseT0iJ0pldEJyYWlucyBNb25vJywnU0YgTW9ubycsJ0ZpcmEgQ29kZScsbW9ub3NwYWNlIiBmb250LXNpemU9IjEzIiBmb250LXdlaWdodD0iNTAwIj4vdmR1dHRzNzwvdGV4dD48L2c+PC9zdmc+" alt="/vdutts7" height="40" /></a>
```

## Implementation

```yaml
script: "agent-driven; no binary"
usage: "add-social-badges [file] [after section] | user says e.g. 'add social badges to README under Contact'"
output: "target file with badge block inserted at specified location"
sources:
  vd7_badge: "inline data URI (black pill, blue circle, vd7.io)"
  vdutts7_badge: "inline data URI (black pill, X logo, /vdutts7)"
```

## Quick Reference

| Intent | Action |
|--------|--------|
| Add badges to README under Contact | Insert badge block after `## Contact` (and optional separator) in README.md |
| Add badges to file X at end | Append badge block to end of X |
| Add badges here | Insert at cursor or after user-specified heading in current file |
