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

wh_state() {
    local base="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima"
    mkdir -p "$base"
    printf '%s\n' "$base"
}

# Shared rate gate for every wallhaven-bound request (API searches, thumbnail
# fetches, picks), so the strip can never trip wallhaven's limits again: the
# documented API cap is 45 calls/min (429 past it), and a Cloudflare WAF has
# also banned whole IPs on request bursts — one such burst here took even a
# cookie'd browser down with a 403. The gate is a rolling-window budget: it
# lets a burst through (so a fresh page of thumbs loads in seconds instead of
# trickling), but caps everything wallhaven-bound at WH_BUDGET (default 30)
# requests per 60s, shared across all processes via a timestamp journal, and
# latches a hard cooling-off period on any throttle/block signal.
wh_state() {
    local base="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima"
    mkdir -p "$base"
    printf '%s\n' "$base"
}

# Suspend all wallhaven traffic for `secs` (default 60). Seeded by any 429/403
# the fetchers see, so a throttle resets the whole pipeline's clock instead of
# letting parts of the UI keep slipping requests through.
wh_backoff() {
    local secs="${1:-60}" base
    base=$(wh_state)
    printf '%s\n' "$(( $(date +%s) + secs ))" > "$base/wh-cooldown.until"
}

wh_gate() {
    local base budget now oldest need_ms count
    base=$(wh_state)
    budget="${WH_BUDGET:-30}"
    { [ "$budget" -gt 0 ] 2>/dev/null; } || budget=30
    exec 9>"$base/wh-window.lock"
    flock 9

    # Cooling-off latch: a recent 429/403 parks every wallhaven request until
    # the timestamp passes. The lock is held throughout so the whole pipeline
    # wakes together instead of trickling back in.
    local cooldown until now_s
    cooldown="$base/wh-cooldown.until"
    if [ -f "$cooldown" ]; then
        until=$(cat "$cooldown" 2>/dev/null || echo 0)
        now_s=$(date +%s)
        if [ "$now_s" -lt "$until" ]; then
            sleep "$(( until - now_s ))"
        fi
        rm -f "$cooldown"
    fi

    window="$base/wh-window.ts"
    while :; do
        now=$(date +%s%N)
        if [ -f "$window" ]; then
            awk -v now="$now" ' $0 + 60000000000 > now ' "$window" > "$window.tmp" \
                && mv "$window.tmp" "$window"
            count=$(wc -l < "$window")
        else
            count=0
        fi
        if [ "$count" -lt "$budget" ]; then
            printf '%s\n' "$now" >> "$window"
            break
        fi
        # Budget exhausted: wait until the oldest in-window request ages out.
        oldest=$(head -1 "$window")
        need_ms=$(( 60000 - (now - oldest) / 1000000 ))
        if [ "$need_ms" -le 250 ]; then
            # Nearly expired anyway — nudge past without a clever sleep.
            sleep 0.3
        else
            sleep "$(awk -v w="$need_ms" 'BEGIN { printf "%.3f", w/1000 }')"
        fi
    done
    flock -u 9
}

# Wallhaven browse/search. An empty query returns the default hot (toplist)
# feed — clicking the strip's wallhaven chip lands there; a query refines it as
# a most-favorited search. The third arg picks the sorting bucket (hot, latest,
# top, random, favorites); with a query, favorites is implied unless
# overridden. The API serves ready-made thumbs, so results are URLs handed
# over to `thumbget` for a paced local copy: nothing is downloaded until the
# strip actually shows it.
whsearch() {
    local query="${1:-}" page="${2:-1}" want="${3:-}"
    case "$page" in
        ''|*[!0-9]*) page=1 ;;
    esac

    local enc sort extra raw code base key mapped
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
        if [ -n "$query" ]; then
            sort="favorites"; extra=""
        else
            sort="toplist"; extra="topRange=1M&"
        fi
    fi

    base=$(wh_state)
    key=$(printf '%s' "$query|$page|$sort" | sha1sum | cut -c1-24)
    cache="$base/wh-cache/$key.json"
    # Dedupe: a repeat of the same query+page+sort within the window replays the
    # stored chunk without any network. The UI re-fires the current page on
    # picks, sort changes and surface re-entry, which used to be a fresh request
    # every time; now those are free.
    if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt 20 ]; then
        cat "$cache"
        return 0
    fi

    wh_gate
    raw=$(curl -s --max-time 15 -w $'\n%{http_code}' -A "$UA" \
        "https://wallhaven.cc/api/v1/search?${query:+q=${enc}&}sorting=${sort}&${extra}order=desc&page=${page}")
    code="${raw##*$'\n'}"
    raw="${raw%$'\n'*}"
    if [ "$code" != "200" ]; then
        # 429 = the documented rate cap (45/min); 403/5xx = WAF block or edge
        # hiccup. Either way latch a hard cooldown so no part of the UI can
        # keep requesting, and hand the UI a pause marker — its slow retry
        # timer owns the re-checks, and this is never cached.
        case "$code" in
            429) wh_backoff 120 ;;
            *)   wh_backoff 60 ;;
        esac
        printf '%s\n' '{"wallhaven":"blocked"}'
        return 0
    fi
    [ -n "$raw" ] || { printf '%s\n' '{"wallhaven":"blocked"}'; return 0; }

    # Map the wallhaven JSON to the strip's entry shape and keep the mapped
    # chunk as the dedupe cache line.
    mapped=$(printf '%s' "$raw" | jq -c '
        .data // []
        | map({
            image: .path,
            thumb: (.thumbs.large // .thumbs.original // ""),
            w: (.dimension_x // 0),
            h: (.dimension_y // 0)
          })
        | map(select(.image != null and .image != ""))
    ' 2>/dev/null || true)
    if [ -n "$mapped" ]; then
        mkdir -p "$base/wh-cache"
        printf '%s\n' "$mapped" > "$cache"
        printf '%s\n' "$mapped"
    else
        printf '%s\n' '{"wallhaven":"blocked"}'
    fi
}

# Fetch one wallhaven thumb into a disk cache at the same shared pace.
# Cached hits are served instantly with no network and no gate (Qt decodes by
# content, so the extensionless cache name is fine), so scrolling back over a
# page costs zero wallhaven requests. The cache is kept under
# WH_THUMB_MAX_MB (default 20): every fresh store prunes the least-recently
# used thumbs (newest just saved is kept) until the directory fits again.
thumbget() {
    local url="${1:-}"
    [ -n "$url" ] || exit 1
    local base digest cache tmp
    base="${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/wh-thumbs"
    mkdir -p "$base"
    digest=$(printf '%s\n' "$url" | sha1sum | cut -c1-24)
    cache="$base/$digest"
    [ -s "$cache" ] && { printf '%s\n' "$cache"; exit 0; }
    wh_gate
    tmp="$base/.$digest.tmp"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL --max-time 25 -A "$UA" -e "https://wallhaven.cc/" -o "$tmp" "$url" \
        || exit 1
    [ -s "$tmp" ] || exit 1
    mv "$tmp" "$cache"
    local max_mb total old
    max_mb="${WH_THUMB_MAX_MB:-20}"
    { [ "$max_mb" -gt 0 ] 2>/dev/null; } || max_mb=20
    total=$(du -sk "$base" 2>/dev/null | awk '{print $1}')
    while [ "${total:-0}" -gt $(( max_mb * 1024 )) ]; do
        old=$(find "$base" -maxdepth 1 -type f ! -name '.*' \
              -printf '%T@ %p\n' | sort -n | head -1 | cut -d' ' -f2-)
        [ -n "$old" ] || break
        rm -f "$old"
        total=$(du -sk "$base" 2>/dev/null | awk '{print $1}')
    done
    printf '%s\n' "$cache"
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
            # it joins the shuffle bag; the filename keeps the wallhaven id. A
            # pick is a wallhaven-bound request too, so it shares the pace gate
            # that protects the API and thumb CDN.
            wh_gate
            fn=$(basename "$url" | tr -d '/\\')
            [ -n "$fn" ] || exit 1
            out="$wpdir/$fn"
            curl -fsL --max-time 600 -A "$UA" -e "https://wallhaven.cc/" -o "$out" "$url" || exit 1
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
    thumbget) thumbget "${2:-}" ;;
    download) download "${2:-}" ;;
    *)        printf '[]\n'; exit 0 ;;
esac
