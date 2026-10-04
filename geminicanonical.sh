#!/usr/bin/env zsh

# SPA URL → clipboard (no dump). For JSON dump use geminicapture.sh.

geminicanonical() {
  local raw="${1:-$(/usr/bin/pbpaste)}"
  local hex
  hex=$(echo "$raw" | /usr/bin/grep -oE '(?:c_)?[0-9a-f]{16,}' | /usr/bin/tail -1 | /usr/bin/sed 's/^c_//')
  [[ -z "$hex" ]] && {
    echo "🔴 usage: geminicanonical <hex-or-url>  (or copy one first)"
    return 1
  }
  echo "https://gemini.google.com/app/${hex}" | /usr/bin/pbcopy
  echo "🟢 ${hex} -> SPA canonical copied. paste in address bar."
  echo "🟢 dump: geminicapture <hex-or-url>"
}

geminicanonical "$@"
