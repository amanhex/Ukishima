#!/usr/bin/env bash
set -eu

SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "Removing Ukishima..."

# Stop a running instance (qs / quickshell started with the ukishima config).
pkill -f "[q]s .*[Uu]kishima" 2>/dev/null || true
pkill -f "[q]uickshell .*[Uu]kishima" 2>/dev/null || true

# Program files (wherever you cloned it).
rm -rf "$SHARE/quickshell/ukishima"
rm -rf "$CONF/quickshell/ukishima"

# State: flags, scratchpad notes, dock pins, gamemode snapshot, wallpaper
# selection, and the wallhaven rate-gate journal.
rm -rf "$STATE/ukishima"

# Calendar events still live in a "pill" sibling rather than under ukishima/,
# so the scrub above never caught them. Remove it on its own.
rm -rf "$STATE/pill"

# Wallpaper state lives in siblings of that dir, one file per setting, and the
# set keeps growing — a .lock file for the bag was missed when the list was
# maintained by hand. Match the prefix instead of enumerating, so a new file is
# covered the moment it is added rather than after someone notices it survived
# an uninstall. Quoted glob: no match must stay a no-op, not a literal rm of
# "$STATE/ukishima-wallpaper*".
for f in "$STATE"/ukishima-wallpaper*; do
  [ -e "$f" ] || continue
  rm -rf "$f"
done

# Cache: weather, rec thumbs, wallpaper + clipboard previews, wallhaven
# search results and thumbs, dynamic colors — all under the single
# ~/.cache/ukishima root. The scattered legacy dirs are removed too so an old
# install is cleaned out fully.
rm -rf "$CACHE/ukishima"
rm -rf "$CACHE/ukishima-wp-thumbs"
rm -rf "$CACHE/cliphist-thumbs"
rm -rf "$CACHE/pill"

# Note: this script never edits your Hyprland config. The auto-launch line and
# the SUPER keybinds were added by you, so remove them yourself:
echo "Ukishima removed."
echo "Remove the exec-once auto-launch line and the SUPER keybinds from your Hyprland config."