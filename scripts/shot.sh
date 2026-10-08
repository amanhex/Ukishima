#!/bin/sh
# Ukishima screenshot studio launcher.
#
# One script, four stills. The pill camera glyph, keybinds and any script call
# this with a mode; it probes the tools, resolves the save directory and execs
# the separate `shot/` Quickshell config. That config is never part of the main
# shell's import graph (like lockscreen/): it reads no singleton, shares no
# state, and quits when the capture lands.
#
#   shot.sh [screen|region|window|color] [monitor]
#
# Region and window freeze the outputs first (grim stills, one per monitor)
# and select on the still, so no picker ever fights the overlay for the
# pointer — the failure mode that killed the old in-surface picker. Screen
# shoots a monitor straight away with no overlay; color runs hyprpicker,
# which copies the hex itself. Env overrides for scripting: SHOT_MODE,
# SHOT_MON, SHOT_DIR. Test doors (unset in production): SHOT_TEST_GEOM
# auto-selects `x,y WxH` on entering select, SHOT_TEST_DRAW stamps one of
# every stroke kind across it — together with wtype they drive the whole
# pipeline with no pointer.
#
# Deps: grim (every capture mode), wl-copy (the saved still is also copied),
# notify-send (saved/copied/error feedback), hyprpicker (color mode only),
# hyprctl (monitor geometry, the client list, the focused monitor). A missing
# tool is stderr + exit 1 — unlike lock.sh there is no safe downgrade for a
# screenshotter, so this fails loudly instead of capturing wrong pixels.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(dirname -- "$SCRIPT_DIR")

MODE="${1:-${SHOT_MODE:-region}}"
MON="${2:-${SHOT_MON:-}}"

case "$MODE" in
    screen | region | window | color) ;;
    *)
        echo "shot.sh: mode must be screen|region|window|color, got '$MODE'" >&2
        exit 2
        ;;
esac

if command -v quickshell >/dev/null 2>&1; then
    QS=quickshell
elif command -v qs >/dev/null 2>&1; then
    QS=qs
else
    echo "shot.sh: neither quickshell nor qs on PATH" >&2
    exit 1
fi

if [ "$MODE" != color ] && ! command -v grim >/dev/null 2>&1; then
    echo "shot.sh: grim not installed — capture modes need it" >&2
    exit 1
fi
if [ "$MODE" = color ] && ! command -v hyprpicker >/dev/null 2>&1; then
    echo "shot.sh: hyprpicker not installed — color mode needs it" >&2
    exit 1
fi
for bin in hyprctl wl-copy notify-send; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "shot.sh: $bin not installed" >&2
        exit 1
    fi
done

# Save dir: explicit env wins, then the persisted flag, then the default.
# (No UI writes shotDir yet; set it with
#  python3 -c "import json; p=...; d=json.load(open(p)); d['shotDir']='/x'; json.dump(d, open(p,'w'))".)
SHOT_DIR="${SHOT_DIR:-$(python3 -c "
import json, os
p = os.path.join(os.environ.get('XDG_STATE_HOME', os.environ['HOME'] + '/.local/state'), 'ukishima/flags.json')
try:
    print(json.load(open(p)).get('shotDir', ''))
except (OSError, ValueError):
    print('')
" 2>/dev/null)}"
if [ -z "$SHOT_DIR" ]; then
    SHOT_DIR="$HOME/Pictures/Screenshots"
fi
mkdir -p "$SHOT_DIR" || exit 1
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/ukishima-shot" || exit 1

export SHOT_MODE="$MODE" SHOT_MON="$MON" SHOT_DIR
exec "$QS" -c "$REPO_DIR/shot"
