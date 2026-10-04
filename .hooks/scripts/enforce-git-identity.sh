#!/usr/bin/env bash
# Machine-wide: sync + verify repo-local identity against identity-routing.
# Canonical = origin when present. Secondary remotes (e.g. github mirror) do not
# change local author identity and must not block commit/push.
set -euo pipefail

TARGET="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MODE="${2:-}"

if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

ROOT_TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)"
HOOK_LIB="${ROOT_TOP}/.hooks/scripts/lib/git-identity-lib.sh"
[[ -f "$HOOK_LIB" ]] && LIB="$HOOK_LIB"
SETUP="${ROOT_TOP}/.hooks/scripts/setup-git-identity.sh"
[[ -f "$LIB" ]] && source "$LIB"

remotes=()
while IFS= read -r r; do
  [[ -n "$r" ]] && remotes+=("$r")
done < <(git -C "$TARGET" remote 2>/dev/null || true)

if [[ ${#remotes[@]} -eq 0 ]]; then
  exit 0
fi

# Prefer origin. Fall back to first routed remote. Never conflict-fail on dual forge.
canonical="origin"
expect_line="$(git_identity_route_for_remote "$TARGET" "origin" 2>/dev/null || true)"
if [[ -z "$expect_line" ]]; then
  canonical=""
  for remote in "${remotes[@]}"; do
    line="$(git_identity_route_for_remote "$TARGET" "$remote" 2>/dev/null || true)"
    [[ -n "$line" ]] || continue
    expect_line="$line"
    canonical="$remote"
    break
  done
fi

[[ -n "$expect_line" ]] || exit 0
[[ -n "$canonical" ]] || canonical="${remotes[0]}"

if [[ "$MODE" == "--sync" || "$MODE" == "--sync-quiet" ]]; then
  if [[ -x "$SETUP" ]]; then
    "$SETUP" "$TARGET" "$canonical" >/dev/null
  fi
  [[ "$MODE" == "--sync-quiet" ]] && MODE="--quiet"
fi

IFS=$'\t' read -r want_name want_email want_ns <<< "$expect_line"
actual_name="$(git -C "$TARGET" config --local user.name 2>/dev/null || true)"
actual_email="$(git -C "$TARGET" config --local user.email 2>/dev/null || true)"

if [[ "$actual_name" != "$want_name" || "$actual_email" != "$want_email" ]]; then
  echo "[enforce-git-identity] BLOCKED: identity mismatch (route ${want_ns:-unknown})" >&2
  echo "  want:   $want_name <$want_email>" >&2
  echo "  actual: ${actual_name:-<unset>} <${actual_email:-unset}>" >&2
  echo "  fix:    $SETUP \"$TARGET\" $canonical" >&2
  exit 1
fi

# Commit author (git am / --author sets GIT_AUTHOR_*; config-only check above is insufficient)
author_name="${GIT_AUTHOR_NAME:-$actual_name}"
author_email="${GIT_AUTHOR_EMAIL:-$actual_email}"
if [[ -f "$LIB" ]] && declare -f git_identity_author_ok >/dev/null 2>&1; then
  if ! git_identity_author_ok "$want_name" "$want_email" "$author_name" "$author_email"; then
    echo "[enforce-git-identity] BLOCKED: commit author mismatch (route ${want_ns:-unknown})" >&2
    echo "  want:   $want_name <$want_email>" >&2
    echo "  author: ${author_name:-<unset>} <${author_email:-unset}>" >&2
    echo "  hint:   git am preserves patch From:- use git am --reset-author or apply + commit locally" >&2
    exit 1
  fi
elif [[ "$author_name" != "$want_name" || "$author_email" != "$want_email" ]]; then
  echo "[enforce-git-identity] BLOCKED: commit author mismatch (route ${want_ns:-unknown})" >&2
  echo "  want:   $want_name <$want_email>" >&2
  echo "  author: ${author_name:-<unset>} <${author_email:-unset}>" >&2
  exit 1
fi

url="$(git -C "$TARGET" config --get "remote.${canonical}.url" 2>/dev/null || true)"
if git_identity_parse_remote_url "$url" 2>/dev/null; then
fi

[[ "$MODE" == "--quiet" ]] || echo "[enforce-git-identity] OK $want_name <$want_email> via $canonical"
exit 0
