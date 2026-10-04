#!/usr/bin/env bash
# Set origin URL from repo.spine.json (remote.origin_url or remote.prefer) or leave as-is (auto)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
CONFIG="${ROOT}/repo.spine.json"
[[ -f "$CONFIG" ]] || { echo "[set-remote] repo.spine.json not found"; exit 1; }
command -v jq &>/dev/null || { echo "[set-remote] jq required"; exit 1; }

sync_identity() {
  local setup_script="${ROOT}/.hooks/scripts/setup-git-identity.sh"
  if [[ -x "$setup_script" ]]; then
    "$setup_script" "$ROOT" origin >/dev/null
  fi
}

origin_url="$(jq -r '.remote.origin_url // empty' "$CONFIG" 2>/dev/null)"
prefer="$(jq -r '.remote.prefer // "auto"' "$CONFIG" 2>/dev/null)"

if [[ -n "$origin_url" && "$origin_url" != "null" ]]; then
  git remote set-url origin "$origin_url"
  echo "[set-remote] origin → $origin_url"
  sync_identity || true
  exit 0
fi

if [[ "$prefer" == "auto" ]]; then
  sync_identity || true
  exit 0
fi

current="$(git config --get remote.origin.url 2>/dev/null)"
[[ -z "$current" ]] && { echo "[set-remote] no remote.origin set"; exit 1; }

if [[ "$current" =~ ^git@([^:]+):(.+)$ ]]; then
  host="${BASH_REMATCH[1]}"
  slug="${BASH_REMATCH[2]%.git}"
elif [[ "$current" =~ ^https?://([^/]+)/(.+)$ ]]; then
  host="${BASH_REMATCH[1]}"
  slug="${BASH_REMATCH[2]%.git}"
else
  echo "[set-remote] could not parse origin URL"; exit 1
fi

case "$prefer" in
  ssh)  newurl="git@${host}:${slug}.git" ;;
  https) newurl="https://${host}/${slug}.git" ;;
  *)    echo "[set-remote] prefer must be ssh|https|auto"; exit 1 ;;
esac

git remote set-url origin "$newurl"
echo "[set-remote] origin → $newurl"
sync_identity || true
