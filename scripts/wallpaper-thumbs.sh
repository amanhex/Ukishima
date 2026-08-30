#!/bin/sh
MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"
export MAGICK_CONFIGURE_PATH

flags="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/flags.json"
wpdir=$(jq -r '.wallpaperDir // ""' "$flags" 2>/dev/null || echo "")
[ -n "$wpdir" ] || wpdir=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-dir" 2>/dev/null || true)
[ -n "$wpdir" ] || wpdir="$HOME/Pictures/Wallpapers"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima-wp-thumbs"
# Each wallpaper folder gets its own subdirectory keyed by the hash of its
# canonical path, so files that share a basename across folders never stomp
# each other and switching folders cannot show a stale thumb from the other
# folder. The same hash is reproduced by the pill's listing command.
key=$(printf %s "$wpdir" | md5sum | cut -d' ' -f1)
dir="$cache/$key"
mkdir -p "$dir"

# Prune thumbs whose source no longer exists, in one pass: the old per-thumb
# `find` spawned a process per file, which dominated the whole refresh on big
# folders. Basenames of the current sources and of every cached thumb are
# collected once each and diffed, so a rename/delete anywhere in the folder is
# caught with two finds instead of one per file.
src_list="$(mktemp)"
have_list="$(mktemp)"
trap 'rm -f "$src_list" "$have_list"' EXIT
find "$wpdir" -type f \( \
    -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \
    -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \
\) -printf '%f\n' | sort -u > "$src_list"
find "$dir" -maxdepth 1 -type f -name '*.png' -printf '%f\n' \
    | sed 's/\.png$//' | sort -u > "$have_list"
comm -23 "$have_list" "$src_list" | while IFS= read -r base; do
    rm -f "$dir/$base.png"
done

find "$wpdir" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \) | while IFS= read -r src; do
    thumb="$dir/$(basename "$src").png"
    if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
        case "$src" in
            *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv])
                ffmpeg -y -loglevel quiet -i "$src" -frames:v 1 -vf 'scale=512:-2' -f image2 -c:v png "$thumb.tmp" 2>/dev/null
                ;;
            *)
                magick "${src}[0]" -strip -resize 512x "png:$thumb.tmp" 2>/dev/null
                ;;
        esac
        if [ -s "$thumb.tmp" ]; then
            mv "$thumb.tmp" "$thumb"
        else
            rm -f "$thumb.tmp"
        fi
    fi
done
