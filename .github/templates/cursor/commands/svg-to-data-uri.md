---
id: svg-to-data-uri
version: 1.0
created: 2026-03-11
category: workflow
layer: 2
type: tool/basic

chains_with: []
depends_on: []
used_by:
  - add-social-badges
usage_stats:
  invocations: 0
---

# svg-to-data-uri

Convert one or more SVG files to `data:image/svg+xml;base64,...` data URIs. Modular utility for embedding SVGs (e.g. badges, icons) without external links.

## Schema

```json
{
  "$schema": "http://json-schema.org/draft-2020-12/schema#",
  "type": "object",
  "required": ["file"],
  "properties": {
    "file": { "type": "string", "description": "Path to SVG file" },
    "files": { "type": "array", "items": { "type": "string" }, "description": "Multiple SVG paths" },
    "minify": { "type": "boolean", "description": "Strip whitespace before encoding (smaller output)" }
  }
}
```

## Execution Rules

```yaml
logic:
  - "Resolve SVG path(s) from user or args"
  - "Run script with each path; optional --minify"
  - "Output: one data URI per line (data:image/svg+xml;base64,...)"

validation:
  - "File(s) exist and are readable"
  - "Output is valid data URI string(s)"

enforcement:
  - "Use script; no inline base64 logic in command"
```

## Implementation

```yaml
script: ".github/templates/cursor/scripts/svg-to-data-uri.sh"
location: ".github/templates/cursor/scripts/svg-to-data-uri.sh"
usage: "svg-to-data-uri.sh [--minify] <file.svg> [file2.svg ...]"
output: "One data URI per input file, one per line"
```

## Quick Reference

| Intent | Command |
|--------|--------|
| Single file | `.github/templates/cursor/scripts/svg-to-data-uri.sh path/to/icon.svg` |
| Multiple files | `.github/templates/cursor/scripts/svg-to-data-uri.sh a.svg b.svg` |
| Minified (smaller) | `.github/templates/cursor/scripts/svg-to-data-uri.sh --minify path/to/icon.svg` |
| Inline in HTML | Use output as `src="<data-uri>"` in `<img>` |

## Script

Bash 3.2+ compatible. Script: `.github/templates/cursor/scripts/svg-to-data-uri.sh`. Reads SVG, base64-encodes, prints `data:image/svg+xml;base64,<b64>`. Option `--minify` collapses whitespace before encoding.
