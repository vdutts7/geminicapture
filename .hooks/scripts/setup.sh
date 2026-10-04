#!/usr/bin/env bash

# .hooks/scripts/setup.sh

# one-time setup post-clone- zero deps



ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT"



git config --local include.path ../.gitconfig

chmod +x .hooks/* .hooks/scripts/*.sh .hooks/scripts/lib/*.sh 2>/dev/null



# Optional: set origin from repo.spine.json (remote.prefer or remote.origin_url)

[[ -f repo.spine.json ]] && command -v jq &>/dev/null && .hooks/scripts/set-remote.sh || true



echo "hooks activated:"

for h in .hooks/pre-*  .hooks/post-*; do

    [[ -f "$h" ]] && echo "  $(basename "$h")"

done


