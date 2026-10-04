#!/usr/bin/env bash
# Block README table markdown images and unscaled Contact/table icons (HTML 40 required).
set -eo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$ROOT" ]] && exit 0

python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path

root = Path(sys.argv[1])
paths = [
    root / "README.md",
    root / ".github/templates/README.template.md",
    root / "templates/README.template.md",
]
md_bang = re.compile(r"^\|.*!\[[^\]]*\]", re.M)
badge = re.compile(
    r"(!\[[^\]]*\]\[badge-(vd7|x)\])"
    r"|(!\[[^\]]*\]\([^\)]*readme-badge-(vd7|x))"
    r"|(readme-badge-(vd7|x)\.png(?![^\n]{0,120}height=\"40\"))"
)
img_tag = re.compile(r"<img\b[\s\S]*?>", re.I)
rc = 0
for path in paths:
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = path.relative_to(root)
    if md_bang.search(text):
        print(f"[pre-commit] {rel}: table markdown image forbidden; use HTML img width=40 height=40", file=sys.stderr)
        rc = 1
    if badge.search(text):
        print(f"[pre-commit] {rel}: social badges must be HTML img height=40", file=sys.stderr)
        rc = 1
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("|") or "![" in s:
            continue
        cell = s.strip("|").split("|")[0]
        for tag in img_tag.findall(cell):
            if 'width="40"' not in tag or 'height="40"' not in tag:
                print(f"[pre-commit] {rel}: table icon img needs width=40 height=40", file=sys.stderr)
                rc = 1
sys.exit(rc)
PY
