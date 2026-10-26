#!/usr/bin/env sh
# Launch Ukishima with jemalloc decay settings. Quickshell links jemalloc; by
# default the allocator keeps freed pages around, so resident memory rides at
# the session's peak instead of the live working set. Turning decay on returns
# unused pages to the OS as the shell churns, which keeps RSS near the live
# working set, and retain:false makes the purge actually drop them from RSS
# (the default retain keeps purged pages mapped as MADV_FREE, so VmRSS sits at
# the peak even after the pages are "freed"). The 100ms decays stay: purging on
# the background thread keeps the returns off the UI's free path, where a 0ms
# decay would put an madvise on every free. This script resolves its own
# location, so it works from any install path (just point your autostart at it).
export MALLOC_CONF="background_thread:true,retain:false,dirty_decay_ms:100,muzzy_decay_ms:100"
# qt.qpa.wayland.textinput joins the log with the system Qt 6.12 update: every
# fresh launch now logs "Trying to disable ... but 0x0 is focused" a few times —
# text-input bookkeeping from the Wayland QPA, new since the update while
# quickshell is still the 6.11 build (its own rebuild WARN is the line that
# matters). No input breaks, so the whole category goes. Appended so it wins
# over pre-set rules.
export QT_LOGGING_RULES="${QT_LOGGING_RULES:+$QT_LOGGING_RULES;}qt.qpa.wayland.textinput=false"
# QtMultimedia's FFmpeg log silencing and the QT_FFMPEG_*_HW_DEVICE_TYPES=vaapi
# exports that used to live here are gone: they existed only to quiet the strip's
# video preview, and nothing in the shell touches QtMultimedia any more (it is
# not even linked by quickshell), so the plugin never loads and never logs. If a
# playback feature comes back, restore both blocks from git history — but
# re-check the `=vaapi` values before keeping them: they hardcoded this
# machine's vendor and are simply wrong on a box without Intel graphics (the
# hw-device list must not be pinned; leave it default unless the vdpau stderr
# line actually appears on your hardware — that one is raw lib output no
# logging rule can touch).
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/scripts/wm.sh"

# Keep Quickshell's existing diagnostics for issue reports. This is passive
# output capture: no watcher or polling process is started.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ukishima"
LOG_FILE="$STATE_DIR/ukishima.log"
if mkdir -p "$STATE_DIR" 2>/dev/null; then
  if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null)" -ge 5242880 ] 2>/dev/null; then
    mv -f -- "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null || true
  fi
  if { : >> "$LOG_FILE"; } 2>/dev/null; then
    exec >> "$LOG_FILE" 2>&1
    printf '\n--- Ukishima launch %s (%s) ---\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$UKISHIMA_WM"
  fi
fi

if command -v quickshell >/dev/null 2>&1; then
  exec quickshell --path "$DIR" "$@"
elif command -v qs >/dev/null 2>&1; then
  exec qs --path "$DIR" "$@"
fi

echo "launch.sh: quickshell not found in PATH" >&2
exit 127
