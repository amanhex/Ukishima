#!/usr/bin/env bash
set -euo pipefail

PURGE_DATA=0
if [ "${1:-}" = "--purge-data" ]; then
  PURGE_DATA=1
elif [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--purge-data]\n' "$0" >&2
  exit 2
fi

: "${HOME:?HOME is not set}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
INSTALL_ROOT="$HOME/.local/share/quickshell/ukishima"

if [ -L "$HOME/.local" ] || [ -L "$HOME/.local/share" ] || \
   [ -L "$HOME/.local/share/quickshell" ] || [ -L "$INSTALL_ROOT" ]; then
  printf 'Installation path is a symlink; leaving it untouched.\n'
  exit 1
fi

if [ -e "$INSTALL_ROOT" ]; then
  if [ ! -f "$INSTALL_ROOT/shell.qml" ] || [ ! -d "$INSTALL_ROOT/components" ] || \
     [ ! -f "$INSTALL_ROOT/scripts/check-deps.sh" ]; then
    printf 'The standard installation path does not contain a Ukishima installation; leaving it untouched.\n' >&2
    exit 1
  fi

  if [ -e "$INSTALL_ROOT/.git" ] || [ -L "$INSTALL_ROOT/.git" ]; then
    if changes=$(git -C "$INSTALL_ROOT" status --porcelain 2>/dev/null); then
      if [ -n "$changes" ]; then
        printf 'Warning: this installation contains local changes or untracked files.\n'
      fi
    else
      printf 'Warning: local changes could not be checked.\n'
    fi
  fi
else
  printf 'Ukishima is not installed.\n'
  if [ "$PURGE_DATA" -eq 0 ]; then exit 0; fi
fi

if [ "$PURGE_DATA" -eq 1 ]; then
  printf 'Remove Ukishima and its settings/cache data? Personal wallpaper files will be kept. [y/N]: '
else
  printf 'Remove Ukishima? Settings and caches will be kept. [y/N]: '
fi
answer=""
IFS= read -r answer 2>/dev/null </dev/tty || answer=""
case "$answer" in
  y|Y|yes|YES) ;;
  *) printf 'Cancelled.\n'; exit 0 ;;
esac

if [ -e "$INSTALL_ROOT" ]; then
  if ! rm -rf -- "$INSTALL_ROOT"; then
    printf 'Could not remove Ukishima from %s.\n' "$INSTALL_ROOT" >&2
    exit 1
  fi
  if [ -e "$INSTALL_ROOT" ] || [ -L "$INSTALL_ROOT" ]; then
    printf 'Could not remove Ukishima from %s.\n' "$INSTALL_ROOT" >&2
    exit 1
  fi
fi

if [ "$PURGE_DATA" -eq 1 ]; then
  if ! rm -rf -- "$STATE_HOME/ukishima" "$CACHE_HOME/ukishima" || ! rm -f -- \
    "$STATE_HOME/ukishima-wallpaper-dir" \
    "$STATE_HOME/ukishima-wallpaper" \
    "$STATE_HOME/ukishima-wallpaper-map" \
    "$STATE_HOME/ukishima-wallpaper-bag" \
    "$STATE_HOME/ukishima-wallpaper-still.png" \
    "$STATE_HOME/ukishima-wallpaper-fit"; then
    printf 'Ukishima was removed, but some settings/cache files could not be removed.\n' >&2
    exit 1
  fi
fi

printf '\n✓ Ukishima removed successfully.\n'
if [ "$PURGE_DATA" -eq 0 ]; then
  printf 'Your personal settings have been preserved.\n'
fi
