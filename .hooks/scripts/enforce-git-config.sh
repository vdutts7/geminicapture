#!/usr/bin/env bash
# Agnostic bundle: verify repo-local git identity via bundled setup-git-identity.sh
exec "$(cd "$(dirname "$0")" && pwd)/enforce-git-identity.sh" "$@"
