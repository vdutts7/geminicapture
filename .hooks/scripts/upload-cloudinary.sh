#!/bin/bash

# .hooks/scripts/upload-cloudinary.sh

# upload assets to Cloudinary

# Reads from env vars (CLOUDINARY_CLOUD_NAME, CLOUDINARY_UPLOAD_PRESET) or repo.spine.json



ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

CONFIG="$ROOT/repo.spine.json"

ICONS_DIR="$ROOT/assets/icons"

SOCIAL="$ROOT/assets/social-preview.png"



# Read Cloudinary config - env vars take priority

CLOUD_NAME="${CLOUDINARY_CLOUD_NAME:-$(jq -r '.cloudinary.cloud_name // empty' "$CONFIG" 2>/dev/null)}"

UPLOAD_PRESET="${CLOUDINARY_UPLOAD_PRESET:-$(jq -r '.cloudinary.upload_preset // empty' "$CONFIG" 2>/dev/null)}"

REPO_NAME=$(jq -r '.repo.name // "project"' "$CONFIG" 2>/dev/null)



# Strip $ prefix if config has placeholder

CLOUD_NAME="${CLOUD_NAME#\$}"

UPLOAD_PRESET="${UPLOAD_PRESET#\$}"



if [[ -z "$CLOUD_NAME" || -z "$UPLOAD_PRESET" || "$CLOUD_NAME" == "CLOUDINARY_CLOUD_NAME" ]]; then

    echo "❌ Cloudinary not configured"

    echo "   Set env vars: CLOUDINARY_CLOUD_NAME, CLOUDINARY_UPLOAD_PRESET"

    exit 1

fi



UPLOAD_URL="https://api.cloudinary.com/v1_1/${CLOUD_NAME}/image/upload"



upload_file() {

    local file="$1"

    local public_id="$2"

    

    RESPONSE=$(curl -sf -X POST "$UPLOAD_URL" \

        -F "file=@$file" \

        -F "upload_preset=$UPLOAD_PRESET" \

        -F "public_id=$public_id" \

        -F "folder=gh-repos/$REPO_NAME")

    

    if [[ $? -eq 0 ]]; then

        URL=$(printf '%s' "$RESPONSE" | jq -r '.secure_url')

        echo "$URL"

    else

        echo ""

    fi

}



echo "→ Uploading to Cloudinary ($CLOUD_NAME)..."



# Upload icons

if [[ -d "$ICONS_DIR" ]]; then

    shopt -s nullglob

    for icon in "$ICONS_DIR"/*.{png,svg,jpg}; do

        [[ -f "$icon" ]] || continue

        NAME=$(basename "$icon" | sed 's/\.[^.]*$//')

        echo -n "  $NAME... "

        URL=$(upload_file "$icon" "$NAME")

        if [[ -n "$URL" ]]; then

            echo "✓ $URL"

        else

            echo "✗ failed"

        fi

    done

    shopt -u nullglob

fi



# Upload social preview

if [[ -f "$SOCIAL" ]]; then

    echo -n "  social-preview... "

    URL=$(upload_file "$SOCIAL" "social-preview")

    if [[ -n "$URL" ]]; then

        echo "✓ $URL"

    else

        echo "✗ failed"

    fi

fi



echo "✓ Done"

echo ""

echo "Base URL: https://res.cloudinary.com/$CLOUD_NAME/image/upload/gh-repos/$REPO_NAME/"


