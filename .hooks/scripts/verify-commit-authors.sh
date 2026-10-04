#!/usr/bin/env bash
# Block push when any outgoing commit author != routed identity (catches git am / wrong --author).
set -euo pipefail

TARGET="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

ROOT_TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)"
HOOK_LIB="${ROOT_TOP}/.hooks/scripts/lib/git-identity-lib.sh"
[[ -f "$HOOK_LIB" ]] && LIB="$HOOK_LIB"
[[ -f "$LIB" ]] && source "$LIB"

expect_line="$(git_identity_expected_for_target "$TARGET" 2>/dev/null || true)"
if [[ -z "$expect_line" ]]; then
  exit 0
fi

IFS=$'\t' read -r want_name want_email want_ns <<< "$expect_line"
bad=0

while read -r local_ref local_sha remote_ref remote_sha; do
  [[ -n "$local_ref" ]] || continue
  if [[ "$local_sha" == 0000000000000000000000000000000000000000 ]]; then
    continue
  fi
  commits=""
  if [[ "$remote_sha" == 0000000000000000000000000000000000000000 ]]; then
    commits="$(git -C "$TARGET" rev-list "$local_sha" 2>/dev/null || true)"
  else
    commits="$(git -C "$TARGET" rev-list "${remote_sha}..${local_sha}" 2>/dev/null || true)"
  fi
  while read -r sha; do
    [[ -n "$sha" ]] || continue
    IFS=$'\t' read -r an ae cn ce < <(
      git -C "$TARGET" show -s --format='%an%x09%ae%x09%cn%x09%ce' "$sha" 2>/dev/null || true
    )
    if [[ -z "$an" && -z "$ae" ]]; then
      if [[ -n "$cn" || -n "$ce" ]]; then
        an="$cn"
        ae="$ce"
      else
        continue
      fi
    fi
    if ! git_identity_author_ok "$want_name" "$want_email" "$an" "$ae"; then
      echo "[verify-commit-authors] BLOCKED: wrong author on $sha (route ${want_ns:-unknown})" >&2
      echo "  want:   $want_name <$want_email>" >&2
      echo "  author: ${an:-<unset>} <${ae:-unset}>" >&2
      echo "  fix:    git commit --amend --author=\"$want_name <$want_email>\"" >&2
      echo "          or rewrite history with git filter-repo mailmap" >&2
      bad=1
    fi
  done <<< "$commits"
done

if [[ "$bad" -ne 0 ]]; then
  exit 1
fi

exit 0
