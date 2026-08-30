#!/usr/bin/env bash

UA="Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/126.0"

search_moewalls() {
    local query="${1:-}"
    UA="$UA" python3 - "$query" <<'PYEOF'
import concurrent.futures
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ua = os.environ.get("UA", "Mozilla/5.0")

def fetch(url, timeout=10):
    req = urllib.request.Request(url, headers={"User-Agent": ua, "Referer": "https://moewalls.com/"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "ignore")

def post_entry(url):
    html = fetch(url)
    prev = re.search(r'<source src="(/wp-content/uploads/preview/[^"]+)"', html)
    token = re.search(r'id="moe-download"[^>]*data-url="([^"]+)"', html)
    thumb = re.search(r'poster="([^"]+)"', html)
    if not prev or not token:
        return None
    res = re.search(r'resolutions-(\d+)x(\d+)', html)
    return {
        "image": "https://go.moewalls.com/download.php?video=" + token.group(1),
        "thumb": urllib.parse.urljoin("https://moewalls.com/", thumb.group(1)) if thumb else "",
        "preview": urllib.parse.urljoin("https://moewalls.com/", prev.group(1)),
        "w": int(res.group(1)) if res else 0,
        "h": int(res.group(2)) if res else 0,
    }

try:
    q = urllib.parse.quote(sys.argv[1])
    page = fetch("https://moewalls.com/?s=" + q, timeout=12)
    posts = []
    for m in re.finditer(r'href="(https://moewalls\.com/[a-z0-9-]+/[a-z0-9-]+-live-wallpaper/)"', page):
        if m.group(1) not in posts:
            posts.append(m.group(1))
    out = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        for entry in ex.map(post_entry, posts[:24]):
            if entry:
                out.append(entry)
    print(json.dumps(out))
except Exception:
    print("[]")
PYEOF
}

# Wallhaven browse/search. An empty query returns the default hot (toplist)
# feed — clicking the strip's wallhaven chip lands there; a query refines it as
# a most-favorited search. The third arg picks the sorting bucket (hot, latest,
# top, random, favorites); with a query, favorites is implied unless
# overridden. The API serves ready-made thumbs, so results are URLs handed
# straight to QML Image: nothing is downloaded or cached until a pick.
whsearch() {
    local query="${1:-}" page="${2:-1}" want="${3:-}"
    case "$page" in
        ''|*[!0-9]*) page=1 ;;
    esac

    local enc sort extra raw
    enc=$(jq -rn --arg q "$query" '$q|@uri') || { printf '[]\n'; return 0; }
    sort="favorites"
    extra=""
    case "$want" in
        latest)    sort="date_added" ;;
        top)       sort="toplist";   extra="topRange=1y&" ;;
        random)    sort="random" ;;
        favorites) sort="favorites" ;;
    esac
    # Hot is the default browse bucket: toplist over the last month. The selected
    # sort is honoured even for browse; a typed query still implies favorites
    # unless the sort dropdown explicitly overrides it.
    if [ -z "$want" ] || [ "$want" = "hot" ]; then
        sort="toplist"; extra="topRange=1M&"
    fi
    raw=$(curl -s --max-time 15 -A "$UA" \
        "https://wallhaven.cc/api/v1/search?${query:+q=${enc}&}sorting=${sort}&${extra}order=desc&page=${page}") \
        || { printf '[]\n'; return 0; }
    [ -n "$raw" ] || { printf '[]\n'; return 0; }

    printf '%s' "$raw" | jq -c '
        .data // []
        | map({
            image: .path,
            thumb: (.thumbs.large // .thumbs.original // ""),
            w: (.dimension_x // 0),
            h: (.dimension_y // 0)
          })
        | map(select(.image != null and .image != ""))
    ' 2>/dev/null || printf '[]\n'
}

search() {
    local query="${1:-}" kind="${2:-all}"
    [ -n "$query" ] || { printf '[]\n'; return 0; }

    if [ "$kind" = "motion" ]; then
        search_moewalls "$query"
        return 0
    fi

    local q="$query" f=",,,"
    case "$kind" in
        still)  f="type:photo" ;;
    esac

    local enc vqd raw
    enc=$(jq -rn --arg q "$q" '$q|@uri') || { printf '[]\n'; return 0; }

    vqd=$(curl -s --max-time 10 "https://duckduckgo.com/?q=${enc}&iax=images&ia=images" -A "$UA" \
        | grep -oP 'vqd=\\?"?\K[0-9-]+' | head -1)
    [ -n "$vqd" ] || { printf '[]\n'; return 0; }

    raw=$(curl -s --max-time 10 \
        "https://duckduckgo.com/i.js?l=us-en&o=json&q=${enc}&vqd=${vqd}&f=${f}&p=-1" \
        -A "$UA" -H "Referer: https://duckduckgo.com/")
    [ -n "$raw" ] || { printf '[]\n'; return 0; }

    printf '%s' "$raw" | jq -c --arg kind "$kind" '
        (.results // [])
        | if $kind == "still" then map(select(.image // "" | test("\\.gif(\\?|$)"; "i") | not)) else . end
        | map({
            image: .image,
            thumb: (.thumbnail // .image),
            w: (.width // 0 | if . == null then 0 else . end),
            h: (.height // 0 | if . == null then 0 else . end)
          })
        | map(select(.image != null and .image != ""))
        | .[0:60]
    ' 2>/dev/null || printf '[]\n'
}

download() {
    set -euo pipefail
    url="${1:-}"
    [ -n "$url" ] || exit 1

    flags="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/flags.json"
    wpdir=$(jq -r '.wallpaperDir // ""' "$flags" 2>/dev/null || echo "")
    [ -n "$wpdir" ] || wpdir=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-dir" 2>/dev/null || true)
    [ -n "$wpdir" ] || wpdir="$HOME/Pictures/Wallpapers"
    # Every pick lands directly in the collection root so it joins the shuffle
    # bag; wallhaven keeps its id, moewalls/DDG get stamped names. No subfolder
    # is ever created, so browsing never leaves an empty downloads/ dir behind.

    case "$url" in
        https://go.moewalls.com/download.php*)
            fn=$(curl -fsI --max-time 20 -A "$UA" -e "https://moewalls.com/" "$url" \
                | grep -oiP 'filename=\K[^"\r\n;]+' | head -1 | tr -d '/\\')
            [ -n "$fn" ] || fn="moewalls-$(date +%s).mp4"
            out="$wpdir/$fn"
            curl -fsL --max-time 600 -A "$UA" -e "https://moewalls.com/" -o "$out" "$url" || exit 1
            [ -s "$out" ] || exit 1
            printf '%s\n' "$out"
            exit 0
            ;;
        https://w.wallhaven.cc/*)
            # Picked wallhaven wallpaper lands in the collection root itself so
            # it joins the shuffle bag; the filename keeps the wallhaven id.
            fn=$(basename "$url" | tr -d '/\\')
            [ -n "$fn" ] || exit 1
            out="$wpdir/$fn"
            curl -fsL --max-time 600 -A "$UA" -o "$out" "$url" || exit 1
            [ -s "$out" ] || exit 1
            printf '%s\n' "$out"
            exit 0
            ;;
    esac

    tmp=$(mktemp "${TMPDIR:-/tmp}/ddg-wp.XXXXXX")
    trap 'rm -f "$tmp" "$tmp.out"' EXIT

    curl -fsL --max-time 60 -A "$UA" -e "https://duckduckgo.com/" -o "$tmp" "$url" || exit 1
    [ -s "$tmp" ] || exit 1

    export MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"

    fmt=$(magick identify -format '%m' "${tmp}[0]" 2>/dev/null | head -1) || exit 1

    case "$fmt" in
        JPEG) ext=jpg ;;
        PNG)  ext=png ;;
        GIF)  ext=gif ;;
        WEBP) ext=webp ;;
        *)    ext=png ;;
    esac

    out="$wpdir/ddg-$(date +%s)-${RANDOM}.${ext}"

    if [ "$ext" = "png" ] && [ "$fmt" != "PNG" ]; then
        magick "${tmp}[0]" -strip "png:$tmp.out" 2>/dev/null || exit 1
        [ -s "$tmp.out" ] || exit 1
        mv "$tmp.out" "$out"
    else
        cp "$tmp" "$out"
    fi

    [ -s "$out" ] || exit 1
    printf '%s\n' "$out"
}

case "${1:-}" in
    search)   search "${2:-}" "${3:-all}" ;;
    whsearch) whsearch "${2:-}" "${3:-1}" "${4:-}" ;;
    download) download "${2:-}" ;;
    *)        printf '[]\n'; exit 0 ;;
esac
