#!/usr/bin/env bash
# Block commits that stage paths inside a Python venv or Conda env.
set -eo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[[ -z "$ROOT" ]] && exit 0

is_inside_venv_or_conda() {
  local abs="$1" dir parent
  [[ -z "$abs" ]] && return 1
  dir=$(dirname "$abs")
  while true; do
    [[ -f "$dir/pyvenv.cfg" ]] && { printf '%s\n' "$dir"; return 0; }
    [[ -d "$dir/conda-meta" ]] && { printf '%s\n' "$dir"; return 0; }
    [[ "$dir" == "$ROOT" ]] && return 1
    parent=$(dirname "$dir")
    [[ "$parent" == "$dir" ]] && return 1
    dir=$parent
  done
}

roots=""
while IFS= read -r f; do
  [[ -z "$f" || "$f" == .git/* ]] && continue
  abs="$ROOT/$f"
  r=$(is_inside_venv_or_conda "$abs" || true)
  [[ -n "$r" ]] && roots="${roots}${r}"$'\n'
done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

roots=$(printf '%s' "$roots" | sort -u | sed '/^$/d' || true)
[[ -z "$roots" ]] && exit 0

rel_from_root() {
  local p="$1"
  case "$p" in
    "$ROOT"/*) printf '%s\n' "${p#"$ROOT"/}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

echo "[pre-commit] BLOCKED - staged files under a Python venv or Conda env:" >&2
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  echo "  $(rel_from_root "$dir")/  (pyvenv.cfg or conda-meta/)" >&2
done <<< "$roots"
echo "[pre-commit] Add that directory to .gitignore, then: git reset HEAD -- <paths>" >&2
exit 1
