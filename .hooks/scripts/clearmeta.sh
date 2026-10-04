#!/bin/zsh

# .hooks/scripts/clearmeta.sh

# self-contained metadata stripper for git hooks. No external host dependency

# usage: clearmeta [ -r ] [ --pdf-safe | --mode=MODE ] <path>

# requires: jq, file. Optional: exiftool (PDF), ffmpeg (media), magick+pdftotext (pdf_safe).

# xattr used when available (macOS/Linux). Manual copy from canonical namespace when updating.



setopt errexit pipefail 2>/dev/null || true

CLEARMETA_REGISTRY='{"default_mode":"generic","mime_to_mode":{"application/pdf":"pdf_safe","audio/mpeg":"media","audio/mp4":"media","audio/x-m4a":"media","video/mp4":"media","video/quicktime":"media","video/x-matroska":"media","audio/flac":"media","audio/wav":"media","audio/ogg":"media","audio/webm":"media","application/octet-stream":"generic","text/plain":"generic","text/html":"generic"},"modes":{"pdf_safe":"clearmeta_pdf_safe","pdf_basic":"clearmeta_pdf_basic","media":"clearmeta_media","generic":"clearmeta_generic"}}'

JQ=$(command -v jq 2>/dev/null) || JQ=jq

get_mime() {

  local path="$1" mime=""

  [[ -z "$path" || ! -e "$path" ]] && return 1

  mime=$(file -bI "$path" 2>/dev/null | sed 's/;.*//' | tr -d ' \n')

  [[ -z "$mime" ]] && return 1

  printf '%s' "$mime"

}

get_mode_for_file() {

  local path="$1" explicit="$2" mime="" mode=""

  [[ -n "$explicit" ]] && mode="$explicit" || {

    mime=$(get_mime "$path") || { echo "clearmeta: could not get MIME for $path" >&2; return 1; }

    mode=$(printf '%s' "$CLEARMETA_REGISTRY" | "$JQ" --arg m "$mime" --arg wild "${mime%%/*}/*" -re '.mime_to_mode[$m] // .mime_to_mode[$wild] // .default_mode' 2>/dev/null) || { echo "clearmeta: unknown MIME $mime" >&2; return 1; }

  }

  [[ -z "$mode" ]] && return 1

  printf '%s' "$mode"

}

clearmeta_generic_filesystem_only() {

  local file="$1" quiet="${2:-}"

  command -v xattr >/dev/null 2>&1 && {

    xattr -d com.apple.metadata:kMDItemWhereFroms "$file" 2>/dev/null

    xattr -d com.apple.metadata:kMDItemDownloadedDate "$file" 2>/dev/null

    xattr -d com.apple.quarantine "$file" 2>/dev/null

    xattr -d com.apple.macl "$file" 2>/dev/null

    xattr -c "$file" 2>/dev/null

  }

  [[ "$quiet" != "quiet" ]] && echo "  Nuked xattrs"

  return 0

}

clearmeta_generic_file() {

  local file="$1" quiet="${2:-}" tmp_file="${file}.clearmeta_tmp_$$" mode=""

  if cat "$file" > "$tmp_file" 2>/dev/null; then

    mode=$(stat -c '%a' "$file" 2>/dev/null) || mode=$(stat -f '%Lp' "$file" 2>/dev/null)

    chmod --reference="$file" "$tmp_file" 2>/dev/null || chmod "$mode" "$tmp_file" 2>/dev/null

    if mv "$tmp_file" "$file" 2>/dev/null; then

      [[ "$quiet" != "quiet" ]] && echo "  Nuked ALL metadata (byte-copy)"

      return 0

    fi

    /bin/unlink "$tmp_file" 2>/dev/null

  fi

  clearmeta_generic_filesystem_only "$file" "$quiet"

  [[ "$quiet" != "quiet" ]] && echo "  Byte-copy failed, cleared xattrs only"

  return 1

}

clearmeta_media() {

  local file="$1" quiet="${2:-}" tmp_file="${file}.ffmpeg_tmp_$$"

  if ! command -v ffmpeg >/dev/null 2>&1; then

    echo "clearmeta: ffmpeg not found" >&2

    return 1

  fi

  if ffmpeg -i "$file" -map 0:a -map_metadata -1 -c:a copy "$tmp_file" -y -loglevel error 2>/dev/null && [[ -s "$tmp_file" ]] && mv "$tmp_file" "$file" 2>/dev/null; then

    [[ "$quiet" != "quiet" ]] && echo "  Stripped embedded media metadata (ffmpeg)"

  else

    /bin/unlink "$tmp_file" 2>/dev/null

  fi

  command -v xattr >/dev/null 2>&1 && {

    xattr -d com.apple.metadata:kMDItemWhereFroms "$file" 2>/dev/null

    xattr -d com.apple.quarantine "$file" 2>/dev/null

    xattr -c "$file" 2>/dev/null

  }

  return 0

}

clearmeta_pdf_basic() {

  local file="$1" quiet="${2:-}"

  if ! command -v exiftool >/dev/null 2>&1; then

    echo "clearmeta: exiftool required for PDF" >&2

    return 1

  fi

  exiftool -all= "$file" -overwrite_original -q 2>/dev/null || return 1

  clearmeta_generic_file "$file" "$quiet"

  return $?

}

clearmeta_pdf_safe() {

  local file="$1" quiet="${2:-}" flat="${file}.flat_$$.pdf"

  for cmd in magick exiftool pdftotext; do

    command -v "$cmd" >/dev/null 2>&1 || { echo "clearmeta: $cmd required for pdf_safe" >&2; return 1; }

  done

  magick -density 200 "$file" -compress jpeg -quality 85 "$flat" 2>/dev/null || { echo "clearmeta: magick flatten failed" >&2; return 1; }

  exiftool -all= "$flat" -overwrite_original -q 2>/dev/null

  clearmeta_generic_file "$flat" "quiet"

  if mv "$flat" "$file" 2>/dev/null; then

    [[ "$quiet" != "quiet" ]] && echo "  Flattened, stripped metadata, nuked xattrs"

    pdftotext "$file" - 2>/dev/null | head -50 | grep -q . && echo "  Warning: text layer present" >&2

    return 0

  fi

  /bin/unlink "$flat" 2>/dev/null

  return 1

}

clearmeta_main() {

  local target="$1" recursive="${2:-false}" explicit_mode="$3" mode="" handler="" f=""

  printf '%s' "$CLEARMETA_REGISTRY" | "$JQ" -e ".modes[.default_mode]" >/dev/null 2>&1 || { echo "clearmeta: invalid registry" >&2; return 1; }

  if [[ "$recursive" == true ]]; then

    [[ ! -d "$target" ]] && { echo "clearmeta: -r requires directory" >&2; return 1; }

    while IFS= read -r f; do

      [[ -z "$f" || ! -f "$f" ]] && continue

      mode=$(get_mode_for_file "$f" "$explicit_mode") || return 1

      handler=$(printf '%s' "$CLEARMETA_REGISTRY" | "$JQ" --arg m "$mode" -re '.modes[$m]') || return 1

      case "$handler" in

        clearmeta_generic) clearmeta_generic_file "$f" "quiet" ;;

        clearmeta_media) clearmeta_media "$f" "quiet" ;;

        clearmeta_pdf_basic) clearmeta_pdf_basic "$f" "quiet" ;;

        clearmeta_pdf_safe) clearmeta_pdf_safe "$f" "quiet" ;;

        *) echo "clearmeta: unknown handler $handler" >&2; return 1 ;;

      esac

    done < <(find "$target" -type f 2>/dev/null)

    command -v xattr >/dev/null 2>&1 && xattr -cr "$target" 2>/dev/null

    return 0

  fi

  [[ -d "$target" ]] && { command -v xattr >/dev/null 2>&1 && xattr -cr "$target" 2>/dev/null; return 0; }

  mode=$(get_mode_for_file "$target" "$explicit_mode") || return 1

  handler=$(printf '%s' "$CLEARMETA_REGISTRY" | "$JQ" --arg m "$mode" -re '.modes[$m]') || return 1

  case "$handler" in

    clearmeta_generic) clearmeta_generic_file "$target" ;;

    clearmeta_media) clearmeta_media "$target" ;;

    clearmeta_pdf_basic) clearmeta_pdf_basic "$target" ;;

    clearmeta_pdf_safe) clearmeta_pdf_safe "$target" ;;

    *) echo "clearmeta: unknown handler $handler" >&2; return 1 ;;

  esac

}

recursive=false

target=""

explicit_mode=""

while [[ $# -gt 0 ]]; do

  case "$1" in

    -h|--help)

      echo "usage: clearmeta [-r] [--pdf-safe | --mode=MODE] <path>"

      echo "  -r, --recursive   process every file under <path> (directory)"

      echo "  --pdf-safe        force PDFs to pdf_safe (flatten+strip)"

      echo "  --mode=MODE       force mode: pdf_safe | pdf_basic | media | generic"

      echo "  <path>            file or directory to strip metadata from"

      exit 0

      ;;

    -r|--recursive) recursive=true; shift ;;

    --pdf-safe) explicit_mode="pdf_safe"; shift ;;

    --mode=*) explicit_mode="${1#--mode=}"; shift ;;

    *) target="$1"; shift ;;

  esac

done

[[ -z "$target" ]] && { echo "clearmeta: path required" >&2; exit 1; }

target=$(eval "echo $target")

target=$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target") || true

[[ -z "$target" || ! -e "$target" ]] && { echo "clearmeta: not found $target" >&2; exit 1; }

echo "CLEARING METADATA: $target"

command -v xattr >/dev/null 2>&1 && echo "BEFORE: $(xattr "$target" 2>/dev/null || echo '(none)')"

clearmeta_main "$target" "$recursive" "$explicit_mode" || exit $?

command -v xattr >/dev/null 2>&1 && echo "AFTER: $(xattr "$target" 2>/dev/null || echo '(none)')"


