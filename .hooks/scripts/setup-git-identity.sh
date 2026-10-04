#!/usr/bin/env bash
# Repo-local identity setup from bundled .hooks/scripts/identity-routing.json
set -euo pipefail

TARGET="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REMOTE="${2:-origin}"
URL_OVERRIDE="${URL:-}"
NAME_OVERRIDE="${NAME:-}"
EMAIL_OVERRIDE="${EMAIL:-}"
REQUIRE_KNOWN_NAMESPACE="${REQUIRE_KNOWN_NAMESPACE:-true}"
ROOT_TOP="$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)"
ROUTES_FILE="${ROUTES_FILE:-${ROOT_TOP}/.hooks/scripts/identity-routing.json}"

if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[setup-git-identity] target is not a git repo: $TARGET" >&2
  exit 1
fi

URL_VALUE="$URL_OVERRIDE"
if [[ -z "$URL_VALUE" ]]; then
  URL_VALUE="$(git -C "$TARGET" config --get "remote.${REMOTE}.url" || true)"
fi
if [[ -z "$URL_VALUE" ]]; then
  echo "[setup-git-identity] missing remote URL (remote.${REMOTE}.url)" >&2
  exit 1
fi

host=""
username=""
if [[ "$URL_VALUE" =~ ^git@([^:]+):([^/]+)/[^/]+(\.git)?$ ]]; then
  host="${BASH_REMATCH[1]}"
  username="${BASH_REMATCH[2]}"
elif [[ "$URL_VALUE" =~ ^ssh://git@([^/]+)/([^/]+)/[^/]+(\.git)?$ ]]; then
  host="${BASH_REMATCH[1]}"
  username="${BASH_REMATCH[2]}"
elif [[ "$URL_VALUE" =~ ^https?://([^/]+)/([^/]+)/[^/]+(\.git)?$ ]]; then
  host="${BASH_REMATCH[1]}"
  username="${BASH_REMATCH[2]}"
else
  echo "[setup-git-identity] could not parse remote URL: $URL_VALUE" >&2
  exit 1
fi

resolved_name="$NAME_OVERRIDE"
resolved_email="$EMAIL_OVERRIDE"
resolved_namespace=""
resolved_ssh_key=""

if [[ -f "$ROUTES_FILE" ]] && command -v jq >/dev/null 2>&1; then
  route_select='select(.username == $user and (.host == $host or .ssh_host_alias == $host))'
  if [[ -z "$resolved_name" ]]; then
    resolved_name="$(jq -r --arg host "$host" --arg user "$username" "
      (.routes[] | ${route_select} | .name) // empty
    " "$ROUTES_FILE" | head -n1)"
  fi
  if [[ -z "$resolved_email" ]]; then
    resolved_email="$(jq -r --arg host "$host" --arg user "$username" "
      (.routes[] | ${route_select} | .email) // empty
    " "$ROUTES_FILE" | head -n1)"
  fi
  resolved_namespace="$(jq -r --arg host "$host" --arg user "$username" "
    (.routes[] | ${route_select} | .namespace) // empty
  " "$ROUTES_FILE" | head -n1)"
  resolved_ssh_key="$(jq -r --arg host "$host" --arg user "$username" "
    (.routes[] | ${route_select} | .ssh_key_path) // empty
  " "$ROUTES_FILE" | head -n1)"

  if [[ -z "$resolved_name" ]]; then
    resolved_name="$(jq -r --arg host "$host" '
      .provider_defaults[$host].name // empty
    ' "$ROUTES_FILE" | head -n1)"
  fi
  if [[ -z "$resolved_email" ]]; then
    resolved_email="$(jq -r --arg host "$host" '
      .provider_defaults[$host].email // empty
    ' "$ROUTES_FILE" | head -n1)"
  fi
  if [[ -z "$resolved_namespace" ]]; then
    resolved_namespace="$(jq -r --arg host "$host" '
      .provider_defaults[$host].namespace // empty
    ' "$ROUTES_FILE" | head -n1)"
  fi
  if [[ -z "$resolved_ssh_key" ]]; then
    resolved_ssh_key="$(jq -r --arg host "$host" '
      .provider_defaults[$host].ssh_key_path // empty
    ' "$ROUTES_FILE" | head -n1)"
  fi
fi

if [[ -z "$resolved_name" || -z "$resolved_email" ]]; then
  if [[ "$REQUIRE_KNOWN_NAMESPACE" == "true" ]]; then
    echo "[setup-git-identity] no identity route for ${host}/${username}; set NAME/EMAIL or edit $ROUTES_FILE" >&2
    exit 1
  fi
  resolved_name="${resolved_name:-$username}"
  resolved_email="${resolved_email:-$username@users.noreply.$host}"
  resolved_namespace="${resolved_namespace:-derived-${host}-${username}}"
fi

git -C "$TARGET" config --local user.name "$resolved_name"
git -C "$TARGET" config --local user.email "$resolved_email"

echo "[setup-git-identity] route=${resolved_namespace:-unknown} remote=$URL_VALUE"
echo "user.name=$resolved_name"
echo "user.email=$resolved_email"
if [[ -n "$resolved_ssh_key" ]]; then
  echo "ssh_key_path=$resolved_ssh_key"
fi
