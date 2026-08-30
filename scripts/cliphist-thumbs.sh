#!/bin/sh
MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"
export MAGICK_CONFIGURE_PATH

# Warm cache of clipboard-image thumbnails, driven by Cliphist.qml on every
# clipboard change. Only image entries get a thumbnail (named by cliphist id);
# missing ones are decoded through the ImageMagick decode cage
# (MAGICK_CONFIGURE_PATH above — clipboard bytes are untrusted input), and
# thumbs whose source entry no longer exists are pruned.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
mkdir -p "$cache"

# One cliphist list snapshot drives both passes, so a refresh never prunes and
# regenerates against two different states.
list="$(cliphist list 2>/dev/null)"

ids="$(mktemp)"
have="$(mktemp)"
trap 'rm -f "$ids" "$have"' EXIT

printf '%s\n' "$list" | cut -f1 | sort -n > "$ids"

# Only prune when the snapshot actually has entries: an empty list here means
# cliphist hiccuped mid-refresh, and wiping the warm cache on that (only to
# re-decode everything on the next pass) is the exact "missing thumb" flare
# this script exists to prevent.
if [ -s "$ids" ]; then
    find "$cache" -maxdepth 1 -type f -name '*.png' -printf '%f\n' \
        | sed 's/\.png$//' | sort -n > "$have"
    comm -23 "$have" "$ids" | while IFS= read -r id; do
        rm -f "$cache/$id.png"
    done
fi

printf '%s\n' "$list" | awk -F '\t' '/\[\[ binary data / && /(png|jpg|jpeg|gif|bmp|webp)/ {print $1}' | while IFS= read -r id; do
    thumb="$cache/$id.png"
    [ -s "$thumb" ] && continue
    if cliphist decode "$id" 2>/dev/null | magick - -strip -resize 128x128 "png:$thumb.tmp" 2>/dev/null; then
        if [ -s "$thumb.tmp" ]; then
            mv "$thumb.tmp" "$thumb"
        else
            rm -f "$thumb.tmp"
        fi
    else
        rm -f "$thumb.tmp"
    fi
done