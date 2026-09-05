#!/bin/sh
recdir="$1"
[ -n "$recdir" ] || exit 0
[ -d "$recdir" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/rec-thumbs"
mkdir -p "$cache"

for f in "$cache"/*.jpg; do
    [ -e "$f" ] || continue
    src="$recdir/$(basename "$f" .jpg).mp4"
    [ -e "$src" ] || rm -f "$f"
done

find "$recdir" -maxdepth 1 -type f -name 'recording_*.mp4' | while IFS= read -r src; do
    thumb="$cache/$(basename "$src" .mp4).jpg"
    if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
        ffmpeg -y -ss 1 -i "$src" -frames:v 1 -vf scale=200:-1 -q:v 4 "$thumb.tmp.jpg" >/dev/null 2>&1
        [ -s "$thumb.tmp.jpg" ] || ffmpeg -y -ss 0 -i "$src" -frames:v 1 -vf scale=200:-1 -q:v 4 "$thumb.tmp.jpg" >/dev/null 2>&1
        if [ -s "$thumb.tmp.jpg" ]; then
            mv "$thumb.tmp.jpg" "$thumb"
        else
            rm -f "$thumb.tmp.jpg"
        fi
    fi
done