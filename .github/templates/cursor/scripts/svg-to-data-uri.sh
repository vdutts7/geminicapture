#!/usr/bin/env bash

# svg-to-data-uri.sh - Convert SVG file(s) to data:image/svg+xml;base64,... (Bash 3.2+)

set -o pipefail 2>/dev/null || true

set -e



MINIFY=""

FILES=()



for arg in "$@"; do

  case "$arg" in

    --minify) MINIFY=1 ;;

    -h|--help)

      echo "Usage: svg-to-data-uri.sh [--minify] <file.svg> [file2.svg ...]"

      echo "Output: data:image/svg+xml;base64,<base64> per file (one per line)"

      exit 0

      ;;

    *) FILES=("${FILES[@]}" "$arg") ;;

  esac

done



if [ ${#FILES[@]} -eq 0 ]; then

  echo "Usage: svg-to-data-uri.sh [--minify] <file.svg> [file2.svg ...]" >&2

  exit 1

fi



for f in "${FILES[@]}"; do

  if [ ! -r "$f" ]; then

    echo "svg-to-data-uri: not readable: $f" >&2

    exit 1

  fi

  if [ -n "$MINIFY" ]; then

    # Collapse newlines and trim extra space between tags for smaller payload

    CONTENT=$(sed 's/>[[:space:]]*</></g' "$f" | tr -d '\n')

  else

    CONTENT=$(cat "$f")

  fi

  B64=$(printf '%s' "$CONTENT" | base64 | tr -d '\n')

  echo "data:image/svg+xml;base64,$B64"

done


