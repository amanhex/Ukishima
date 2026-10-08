#!/usr/bin/env sh
# Launch Ukishima with jemalloc decay settings. Quickshell links jemalloc; by
# default the allocator keeps freed pages around, so resident memory rides at
# the session's peak instead of the live working set. Turning decay on returns
# unused pages to the OS as the shell churns, which keeps RSS near the live
# working set. This script resolves its own location, so it works from any
# install path (just point your autostart at it).
export MALLOC_CONF="background_thread:true,dirty_decay_ms:100,muzzy_decay_ms:100"
# QtMultimedia's FFmpeg backend announces its build on start and dumps an
# "Input #0, ..." block for every video it opens (the wallpaper preview), and
# both land in the session log on every reload. Both are info-level messages
# under qt.multimedia.*; quickshell's own INFO/WARN lines and any real playback
# warning or error keep flowing. Appended so it wins over pre-set rules.
#
# qt.qpa.wayland.textinput joined them with the system Qt 6.12 update: every
# fresh launch now logs "Trying to disable ... but 0x0 is focused" a few
# times — text-input bookkeeping from the Wayland QPA, new since the update
# while quickshell is still the 6.11 build (its own rebuild WARN is the line
# that matters). No input breaks, so the whole category goes.
export QT_LOGGING_RULES="${QT_LOGGING_RULES:+$QT_LOGGING_RULES;}qt.multimedia.*.info=false;qt.qpa.wayland.textinput=false"
# Qt 6.12's FFmpeg plugin enumerates hw device types by *creating* a device
# for each, for the decode list and the encode list separately. The vdpau
# attempt runs libvdpau, which dlopens a backend this Intel machine does not
# have and prints "Failed to open VDPAU backend libvdpau_nvidia.so ..." straight
# to stderr — raw lib output, so no logging rule can touch it. vaapi is the
# hardware that actually exists here, and the encode list is the one that
# fires during plain playback (testing: DECODING alone still printed the
# line, both together went clean). Set either variable yourself to override.
: "${QT_FFMPEG_DECODING_HW_DEVICE_TYPES:=vaapi}"
: "${QT_FFMPEG_ENCODING_HW_DEVICE_TYPES:=vaapi}"
export QT_FFMPEG_DECODING_HW_DEVICE_TYPES QT_FFMPEG_ENCODING_HW_DEVICE_TYPES
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v quickshell >/dev/null 2>&1; then
  exec quickshell --config "$DIR" "$@"
elif command -v qs >/dev/null 2>&1; then
  exec qs -c "$DIR" "$@"
fi

echo "launch.sh: quickshell not found in PATH" >&2
exit 127