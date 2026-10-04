#!/usr/bin/env bash
# Shared identity-routing lookup (host, ssh alias, username -> name/email).
set -euo pipefail

git_identity_routes_file() {
  # NEVER read product-repo copies — those cross-link forge accounts in plaintext.
  # Operator SSOT only (machine-local registry).
  if [[ -n "${GIT_IDENTITY_ROUTES_FILE:-}" && -f "${GIT_IDENTITY_ROUTES_FILE}" ]]; then
    printf '%s' "${GIT_IDENTITY_ROUTES_FILE}"
    return
  fi
}

git_identity_parse_remote_url() {
  local url="$1"
  host="" username=""
  if [[ "$url" =~ ^git@([^:]+):([^/]+)/[^/]+(\.git)?$ ]]; then
    host="${BASH_REMATCH[1]}"
    username="${BASH_REMATCH[2]}"
  elif [[ "$url" =~ ^ssh://git@([^/]+)/([^/]+)/[^/]+(\.git)?$ ]]; then
    host="${BASH_REMATCH[1]}"
    username="${BASH_REMATCH[2]}"
  elif [[ "$url" =~ ^https?://([^/]+)/([^/]+)/[^/]+(\.git)?$ ]]; then
    host="${BASH_REMATCH[1]}"
    username="${BASH_REMATCH[2]}"
  else
    return 1
  fi
  return 0
}

git_identity_lookup_route() {
  local host="$1" username="$2"
  local routes_file line
  routes_file="$(git_identity_routes_file)"
  if [[ ! -f "$routes_file" ]] || ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  line="$(jq -r --arg host "$host" --arg user "$username" '
    (.routes[] | select(.username == $user and (.host == $host or .ssh_host_alias == $host))
      | "\(.name)\t\(.email)\t\(.namespace)") // empty
  ' "$routes_file" | head -n1)"
  if [[ -z "$line" ]]; then
    line="$(jq -r --arg host "$host" '
      (.provider_defaults[$host] | select(. != null)
        | "\(.name)\t\(.email)\t\(.namespace // "")") // empty
    ' "$routes_file" | head -n1)"
  fi
  [[ -n "$line" ]] || return 1
  printf '%s' "$line"
}

git_identity_route_for_remote() {
  local target="$1" remote="$2"
  local url line host username
  url="$(git -C "$target" config --get "remote.${remote}.url" 2>/dev/null || true)"
  [[ -n "$url" ]] || return 1
  git_identity_parse_remote_url "$url" || return 1
  line="$(git_identity_lookup_route "$host" "$username")"
  [[ -n "$line" ]] || return 1
  printf '%s' "$line"
}

# Resolve expected name/email/ns for a repo.
# Canonical = origin when present. Secondary remotes (github mirror, etc.) ignored for author.
# Prints tab-separated line or returns 1.
git_identity_expected_for_target() {
  local target="$1"
  local remotes=() remote line expect_line

  # Prefer origin.
  line="$(git_identity_route_for_remote "$target" "origin" 2>/dev/null || true)"
  if [[ -n "$line" ]]; then
    printf '%s' "$line"
    return 0
  fi

  while IFS= read -r r; do
    [[ -n "$r" ]] && remotes+=("$r")
  done < <(git -C "$target" remote 2>/dev/null || true)
  [[ ${#remotes[@]} -gt 0 ]] || return 1
  for remote in "${remotes[@]}"; do
    line="$(git_identity_route_for_remote "$target" "$remote" 2>/dev/null || true)"
    [[ -n "$line" ]] || continue
    printf '%s' "$line"
    return 0
  done
  return 1
}

# Return 0 if author name+email match expected routed identity.
git_identity_author_ok() {
  local want_name="$1" want_email="$2" author_name="$3" author_email="$4"
  [[ "$author_name" == "$want_name" && "$author_email" == "$want_email" ]]
}
