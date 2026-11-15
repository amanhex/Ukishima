#!/bin/sh
# File-tray preview: print a cached still for a file, generating it on first
# use. Only video needs one — images are drawn straight from the source by the
# tile (sourceSize caps the decode) and text files get a live excerpt, so this
# stays on the tools the wallpaper/recording previews already depend on
# (ffmpeg) and adds nothing new.
#
#   tray-thumbs.sh <file>   -> prints the png path, or nothing if unrenderable
#
# The key carries the source mtime, so an edited video regenerates instead of
# showing a stale frame. Old keys are not pruned; they are small and bounded by
# how many videos the tray has ever held.
src="$1"
[ -f "$src" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/file-tray-thumbs"
mkdir -p "$cache" || exit 0

key="$(printf '%s' "$src" | sha256sum | cut -c1-16)"
stamp="$(stat -c %Y -- "$src" 2>/dev/null || echo 0)"
out="$cache/$key-$stamp.png"
if [ -s "$out" ]; then
    printf '%s\n' "$out"
    exit 0
fi

case "$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')" in
    *.mp4 | *.mkv | *.webm | *.mov | *.avi | *.m4v)
        ffmpeg -y -ss 1 -i "$src" -frames:v 1 -vf scale=320:-2 "$out.tmp.png" >/dev/null 2>&1 \
            || ffmpeg -y -ss 0 -i "$src" -frames:v 1 -vf scale=320:-2 "$out.tmp.png" >/dev/null 2>&1
        ;;
esac

if [ -s "$out.tmp.png" ]; then
    mv -f "$out.tmp.png" "$out"
else
    rm -f "$out.tmp.png"
fi

[ -s "$out" ] && printf '%s\n' "$out"
