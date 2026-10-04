#!/usr/bin/env bash
# Pre-commit: replace Unicode en/em dash (U+2013/U+2014) with hyphen in staged text; re-stage; never block.

set -eo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1

git rev-parse --verify HEAD >/dev/null 2>&1 || exit 0

EM_DASH_PY="$ROOT/.hooks/scripts/lib/em-dash-fix.py"
[[ -f "$EM_DASH_PY" ]] || EM_DASH_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/em-dash-fix.py"
[[ -f "$EM_DASH_PY" ]] || { echo "[pre-commit] check-em-dashes: missing em-dash-fix.py" >&2; exit 0; }

should_skip_path() {
  case "$1" in
    node_modules/* | .git/* | .hooks/* | */fix-em-dashes*.sh) return 0 ;;
  esac
  return 1
}

is_binary_in_cached_diff() {
  local path="$1"
  local line
  line=$(git diff --cached --numstat -- "$path" 2>/dev/null | head -n 1)
  [[ "$line" == $'-\t-\t'* ]]
}

fixed_any=false

while IFS= read -r -d '' path; do
  [[ -z "$path" ]] && continue
  should_skip_path "$path" && continue
  [[ "$(git cat-file -t ":$path" 2>/dev/null)" == blob ]] || continue
  is_binary_in_cached_diff "$path" && continue
  [[ -f "$path" ]] || continue

  em_count=$(git show ":$path" 2>/dev/null | python3 "$EM_DASH_PY" --count)
  [[ "${em_count:-0}" -eq 0 ]] && continue

  if python3 "$EM_DASH_PY" "$path"; then
    git add -- "$path" 2>/dev/null || true
    fixed_any=true
    echo "[pre-commit] check-em-dashes: $path ($em_count dash(es) -> hyphen)"
  fi
done < <(git diff --cached -z --name-only --diff-filter=ACM 2>/dev/null || true)

if $fixed_any; then
  echo "[pre-commit] em dashes replaced with hyphens"
fi

exit 0
