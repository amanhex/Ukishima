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

# State: flags, events, gamemode snapshot, wallpaper selection.
rm -rf "$STATE/ukishima"
rm -f  "$STATE/ukishima-wallpaper-dir"
rm -f  "$STATE/ukishima-wallpaper"
rm -f  "$STATE/ukishima-wallpaper-map"
rm -f  "$STATE/ukishima-wallpaper-bag"
rm -f  "$STATE/ukishima-wallpaper-fit"
rm -f  "$STATE/ukishima-wallpaper-still.png"

# Cache: rec thumbs, wallpaper + clipboard previews, weather location.
rm -rf "$CACHE/ukishima"
rm -rf "$CACHE/ukishima-wp-thumbs"
rm -rf "$CACHE/cliphist-thumbs"
rm -rf "$CACHE/pill"

# Note: this script never edits your Hyprland config. The auto-launch line and
# the SUPER keybinds were added by you, so remove them yourself:
echo "Ukishima removed."
echo "Remove the exec-once auto-launch line and the SUPER keybinds from your Hyprland config."