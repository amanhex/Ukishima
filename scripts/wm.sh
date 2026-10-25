#!/bin/sh
# The one compositor flag for the helper scripts.
#
# Sourcing this sets UKISHIMA_WM to hyprland, niri, or generic. It replaces the
# per-script HYPRLAND_INSTANCE_SIGNATURE / NIRI_SOCKET checks, so one place
# decides what session this is instead of every script deciding again.
#
# A live niri socket takes precedence over a stale override. In other contexts
# UKISHIMA_WM explicitly selects a mode, which is useful for installer checks
# launched outside the session. With no override or live marker,
# XDG_CURRENT_DESKTOP is the fallback:
#   hypr, hyprland -> hyprland
#   niri           -> niri
#   generic        -> generic
if [ -n "${NIRI_SOCKET:-}" ]; then
    # A live niri socket wins over stale overrides inherited from another
    # compositor session, matching the QML provider selection.
    UKISHIMA_WM=niri
else
    case "${UKISHIMA_WM:-}" in
        hypr | hyprland) UKISHIMA_WM=hyprland ;;
        niri) UKISHIMA_WM=niri ;;
        generic) UKISHIMA_WM=generic ;;
        *)
            if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                UKISHIMA_WM=hyprland
            else
                case "${XDG_CURRENT_DESKTOP:-}" in
                    *Hyprland* | *hyprland*) UKISHIMA_WM=hyprland ;;
                    *niri* | *Niri*) UKISHIMA_WM=niri ;;
                    *) UKISHIMA_WM=generic ;;
                esac
            fi
            ;;
    esac
fi
export UKISHIMA_WM
