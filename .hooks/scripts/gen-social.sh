#!/bin/bash

# .hooks/scripts/gen-social.sh - generate GitHub social preview from config

# reads title from repo.spine.json, uses icons from assets/icons/*



ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

CONFIG="$ROOT/repo.spine.json"

ICONS_DIR="$ROOT/assets/icons"

OUT="$ROOT/assets/social-preview.png"



mkdir -p "$ROOT/assets"



# Read title from config

TITLE=$(jq -r '.social_preview.title // .repo.name' "$CONFIG" 2>/dev/null)

[[ -z "$TITLE" || "$TITLE" == "null" ]] && TITLE="PROJECT_NAME"



# Use bg.png if exists, otherwise solid gray

BG="$ROOT/assets/bg.png"

if [[ -f "$BG" ]]; then

    magick "$BG" -resize 1280x640! PNG24:/tmp/bg.png

else

    magick -size 1280x640 canvas:'rgb(224,224,224)' PNG24:/tmp/bg.png

fi



# Collect icons

shopt -s nullglob

FILES=("$ICONS_DIR"/*.png "$ICONS_DIR"/*.svg)

shopt -u nullglob



if [[ ${#FILES[@]} -gt 0 ]]; then

    ICON_SIZE=70

    ICON_GAP=40

    COUNT=${#FILES[@]}

    TOTAL_WIDTH=$(( COUNT * ICON_SIZE + (COUNT - 1) * ICON_GAP ))

    START_X=$(( (1280 - TOTAL_WIDTH) / 2 ))

    ICON_Y=200

    

    cp /tmp/bg.png /tmp/with-icons.png

    

    X_POS=$START_X

    for icon in "${FILES[@]}"; do

        magick "$icon" -resize ${ICON_SIZE}x${ICON_SIZE} -background none PNG32:/tmp/icon.png 2>/dev/null && \

        magick /tmp/with-icons.png /tmp/icon.png -gravity northwest -geometry +${X_POS}+${ICON_Y} -composite PNG24:/tmp/with-icons.png

        X_POS=$((X_POS + ICON_SIZE + ICON_GAP))

    done

    

    magick /tmp/with-icons.png \

        -gravity center \

        -font Helvetica-Bold -pointsize 90 \

        -fill black -annotate +0+100 "$TITLE" \

        PNG24:"$OUT"

else

    magick /tmp/bg.png \

        -gravity center \

        -font Helvetica-Bold -pointsize 90 \

        -fill black -annotate +0+0 "$TITLE" \

        PNG24:"$OUT"

fi



echo "✓ $OUT"


