#!/bin/sh
# The one compositor flag for the helper scripts.
#
# Sourcing this sets UKISHIMA_WM to hyprland, niri, or generic. It replaces the
# per-script HYPRLAND_INSTANCE_SIGNATURE / NIRI_SOCKET checks, so one place
# decides what session this is instead of every script deciding again.
#
# The compositor already exports its own variable once at login; this names the
# result. UKISHIMA_WM overrides detection for testing, matching the shell:
#   hypr, hyprland -> hyprland
#   niri           -> niri
#   generic        -> generic
case "${UKISHIMA_WM:-}" in
    hypr | hyprland) UKISHIMA_WM=hyprland ;;
    niri) UKISHIMA_WM=niri ;;
    generic) UKISHIMA_WM=generic ;;
    *)
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            UKISHIMA_WM=hyprland
        elif [ -n "${NIRI_SOCKET:-}" ]; then
            UKISHIMA_WM=niri
        else
            case "${XDG_CURRENT_DESKTOP:-}" in
                *Hyprland* | *hyprland*) UKISHIMA_WM=hyprland ;;
                *niri* | *Niri*) UKISHIMA_WM=niri ;;
                *) UKISHIMA_WM=generic ;;
            esac
        fi
        ;;
esac
export UKISHIMA_WM
