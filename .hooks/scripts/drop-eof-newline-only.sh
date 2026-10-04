#!/usr/bin/env bash
# drop-eof-newline-only.sh - silent pre-commit cleanup (never blocks)
set -euo pipefail

[[ "${DROP_EOF_NEWLINE:-1}" == "0" ]] && exit 0

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT"
git rev-parse --verify HEAD >/dev/null 2>&1 || exit 0

exec python3 - <<'PY'
import subprocess
from pathlib import Path
from typing import Optional

def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(list(args), capture_output=True)

def is_binary_cached(path: str) -> bool:
    r = run("git", "diff", "--cached", "--numstat", "--", path)
    if r.returncode != 0 or not r.stdout:
        return False
    first = r.stdout.decode("utf-8", "replace").split()[0]
    return first == "-"

def blob(ref: str) -> Optional[bytes]:
    r = run("git", "show", ref)
    return r.stdout if r.returncode == 0 else None

staged_raw = subprocess.check_output(
    ["git", "diff", "--cached", "--name-only", "-z", "--diff-filter=ACM"],
)
dropped: list = []

for raw in staged_raw.split(b"\0"):
    if not raw:
        continue
    path = raw.decode("utf-8", "surrogateescape")
    if is_binary_cached(path):
        continue
    head_b = blob(f"HEAD:{path}")
    stage_b = blob(f":{path}")
    if head_b is None or stage_b is None:
        continue
    if head_b.rstrip(b"\n") != stage_b.rstrip(b"\n"):
        continue
    if head_b == stage_b:
        continue
    wt_b = Path(path).read_bytes() if Path(path).is_file() else stage_b
    restore_worktree = wt_b == stage_b
    cmd = ["git", "restore", "--source=HEAD", "--staged"]
    if restore_worktree:
        cmd.append("--worktree")
    cmd.extend(["--", path])
    subprocess.run(cmd, check=True)
    dropped.append(path)

if dropped:
    print("[pre-commit] dropped eof-newline-only:", " ".join(dropped))
PY
