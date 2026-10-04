#!/usr/bin/env python3
"""Replace Unicode en/em dash in text. Does not touch \\u2013/\\u2014 escape sequences."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

DASHES = ("\u2013", "\u2014")


def count_dashes(text: str) -> int:
    return sum(text.count(ch) for ch in DASHES)


def fix_text(text: str) -> tuple[str, int]:
    n = count_dashes(text)
    if n == 0:
        return text, 0
    out = text
    for ch in DASHES:
        out = out.replace(ch, "-")
    return out, n


def fix_file(path: Path) -> int:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return 0
    fixed, n = fix_text(text)
    if n == 0:
        return 0
    path.write_text(fixed, encoding="utf-8")
    return n


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", action="store_true", help="read stdin; print dash count")
    parser.add_argument("paths", nargs="*", help="fix files in place")
    args = parser.parse_args()

    if args.count:
        text = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        print(count_dashes(text))
        return 0

    if not args.paths:
        parser.error("paths required unless --count")

    changed = 0
    for raw in args.paths:
        n = fix_file(Path(raw))
        if n:
            changed += 1
    return 0 if changed else 1


if __name__ == "__main__":
    raise SystemExit(main())
