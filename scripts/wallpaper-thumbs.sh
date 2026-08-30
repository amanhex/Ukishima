#!/bin/sh
MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"
export MAGICK_CONFIGURE_PATH

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
flags="$STATE/ukishima/flags.json"
raw=$(jq -r '.wallpaperDir // ""' "$flags" 2>/dev/null || echo "")
[ -n "$raw" ] || raw=$(cat "$STATE/ukishima-wallpaper-dir" 2>/dev/null || true)
[ -n "$raw" ] || raw="$HOME/Pictures/Wallpapers"
# Drop any trailing slash so a flags/state trailing-slash drift cannot spawn a
# second cache directory (the folder hash must match the pill's listing hash).
wpdir=$(printf %s "$raw" | sed 's#/*$##')
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima-wp-thumbs"
# Each wallpaper folder gets its own subdirectory keyed by the hash of its
# normalized path, so files that share a basename across folders never stomp
# each other and switching folders cannot show a stale thumb from the other
# folder. The same hash is reproduced by the pill's listing command.
key=$(printf %s "$wpdir" | md5sum | cut -d' ' -f1)
dir="$cache/$key"
mkdir -p "$dir"
# Store the folder this cache dir belongs to so the sweep below can tell
# drift-duplicates and vanished folders apart from folders still in use.
printf %s "$wpdir" > "$dir/.srcdir"

sources() { # $1 = source folder; prints basenames of its wallpapers, sorted
    find "$1" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' \
        -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \
        -o -iname '*.mkv' -o -iname '*.mov' \) -printf '%f\n' | sort -u
}

thumbs() { # $1 = cache subdir; prints its thumb basenames sans .png, sorted
    find "$1" -maxdepth 1 -type f -name '*.png' -printf '%f\n' \
        | sed 's/\.png$//' | sort -u
}

# Keep a cache subdir down to thumbs whose source file still exists. The old
# per-thumb `find` spawned a process per file, which dominated a whole refresh
# on big folders; collecting basenames once and diffing catches every
# rename/delete with two finds instead of one per file.
prune_dir() { # $1 = thumb dir, $2 = source folder
    s=$(mktemp)
    h=$(mktemp)
    sources "$2" > "$s"
    thumbs "$1" > "$h"
    comm -23 "$h" "$s" | while IFS= read -r base; do
        rm -f "$1/$base.png"
    done
    rm -f "$s" "$h"
}

# Active folder: prune stale thumbs, then regenerate missing or outdated ones.
prune_dir "$dir" "$wpdir"

find "$wpdir" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' \
    -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \
    -o -iname '*.mkv' -o -iname '*.mov' \) | while IFS= read -r src; do
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

# Sweep every other cache subdir so the cache never holds thumbs that no
# wallpaper still needs. A subdir survives only when its own folder exists and
# differs from the active one; it is pruned against that folder's current
# files (no regeneration — it warms up again if it is ever activated). Every
# other subdir is dropped whole: drift-duplicates of the active folder (the
# hash of their raw path matches, trailing slash or not), folders that have
# since moved or vanished, and marker-less strays. The pill's listing and the
# strip resolve the same key, so after a sweep thumb pngs match the wallpaper
# count exactly.
raw_flags=$(jq -r '.wallpaperDir // ""' "$flags" 2>/dev/null || echo "")
raw_state=$(cat "$STATE/ukishima-wallpaper-dir" 2>/dev/null || true)
for d in "$cache"/*/; do
    [ -d "$d" ] || continue
    k=$(basename "$d")
    [ "$k" = "$key" ] && continue
    if [ -f "$d/.srcdir" ]; then
        src=$(cat "$d/.srcdir")
    else
        # Legacy subdir (pre-marker): attribute it by hashing the raw path
        # values we know, any of which may have had a trailing slash.
        src=""
        for r in "$raw_flags" "$raw_state"; do
            [ -n "$r" ] || continue
            if [ "$(printf %s "$r" | md5sum | cut -d' ' -f1)" = "$k" ]; then
                src="$r"
                break
            fi
        done
    fi
    nsrc=$(printf %s "$src" | sed 's#/*$##')
    if [ -n "$nsrc" ] && [ -d "$nsrc" ] && [ "$nsrc" != "$wpdir" ]; then
        printf %s "$nsrc" > "$d/.srcdir"
        prune_dir "$d" "$nsrc"
        if [ -z "$(find "$d" -maxdepth 1 -type f -name '*.png' -print -quit)" ]; then
            rm -rf "$d"
        fi
    else
        rm -rf "$d"
    fi
done