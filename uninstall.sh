#!/usr/bin/env bash
set -euo pipefail

KEEP_DATA=0
case "${1:-}" in
  '') [[ $# -eq 0 ]] || exit 2 ;;
  --keep-data) [[ $# -eq 1 ]] || exit 2; KEEP_DATA=1 ;;
  *) printf 'Usage: %s [--keep-data]\n' "$0" >&2; exit 2 ;;
esac

: "${HOME:?HOME is not set}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
INSTALL_ROOT="$HOME/.local/share/quickshell/ukishima"

# Refuse unexpected roots and symlinked directory components before deletion.
for base in "$HOME" "$STATE_HOME" "$CACHE_HOME"; do
  [[ -n "$base" && "$base" != / && "$base" != . && "$base" != .. ]] || {
    printf 'Unsafe storage path: %s\n' "$base" >&2; exit 1;
  }
done
for path in "$HOME/.local" "$HOME/.local/share" "$HOME/.local/share/quickshell" "$INSTALL_ROOT" \
            "$STATE_HOME" "$STATE_HOME/ukishima" "$CACHE_HOME" "$CACHE_HOME/ukishima"; do
  if [[ -L "$path" ]]; then
    printf 'Refusing symlinked path: %s\n' "$path" >&2
    exit 1
  fi
done

if [[ -e "$INSTALL_ROOT" ]]; then
  if [[ ! -f "$INSTALL_ROOT/shell.qml" || ! -d "$INSTALL_ROOT/components" || \
        ! -f "$INSTALL_ROOT/scripts/check-deps.sh" ]]; then
    printf 'Refusing to remove an unrecognized installation: %s\n' "$INSTALL_ROOT" >&2
    exit 1
  fi
  if [[ -e "$INSTALL_ROOT/.git" ]] && command -v git >/dev/null 2>&1; then
    changes=$(git -C "$INSTALL_ROOT" status --porcelain 2>/dev/null || true)
    [[ -z "$changes" ]] || printf 'Warning: installed files contain local changes.\n'
  fi
else
  printf 'Ukishima application files are not installed; checking application data.\n'
fi

if (( KEEP_DATA )); then
  printf 'Remove Ukishima application files, keeping settings and caches? [y/N]: '
else
  printf 'Remove Ukishima, including its settings, state and caches? [y/N]: '
fi
answer=''
IFS= read -r answer </dev/tty 2>/dev/null || answer=''
case "$answer" in
  y|Y|yes|YES) ;;
  *) printf 'Cancelled.\n'; exit 0 ;;
esac

if [[ -d "$INSTALL_ROOT" ]]; then
  rm -rf -- "$INSTALL_ROOT"
fi

if (( ! KEEP_DATA )); then
  rm -rf -- "$STATE_HOME/ukishima" "$CACHE_HOME/ukishima"

  # Legacy wallpaper state stored directly under XDG_STATE_HOME.
  rm -f -- \
    "$STATE_HOME/ukishima-wallpaper-dir" \
    "$STATE_HOME/ukishima-wallpaper" \
    "$STATE_HOME/ukishima-wallpaper-map" \
    "$STATE_HOME/ukishima-wallpaper-bag" \
    "$STATE_HOME/ukishima-wallpaper-fit" \
    "$STATE_HOME/ukishima-wallpaper-still.png"

  # Generated still frames for individual monitors (not original wallpapers).
  shopt -s nullglob
  for still in "$STATE_HOME"/ukishima-wallpaper-still-*.png; do
    [[ -L "$still" ]] && continue
    rm -f -- "$still"
  done
fi

printf '\nUkishima uninstalled successfully.\n'
if (( KEEP_DATA )); then
  printf 'Settings and caches were preserved.\n'
else
  printf 'Ukishima settings, state and caches were removed.\n'
fi
printf 'Your original wallpapers, applications and compositor configuration were not changed.\n'
