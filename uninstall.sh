#!/usr/bin/env bash
set -eu

keep_data=0
case "${1:-}" in
  '') [[ $# -eq 0 ]] || { printf 'Usage: %s [--keep-data]\n' "$0" >&2; exit 2; } ;;
  --keep-data) [[ $# -eq 1 ]] || { printf 'Usage: %s [--keep-data]\n' "$0" >&2; exit 2; }; keep_data=1 ;;
  *) printf 'Usage: %s [--keep-data]\n' "$0" >&2; exit 2 ;;
esac

: "${HOME:?HOME is not set}"
root="$HOME/.local/share/quickshell/ukishima"
state="${XDG_STATE_HOME:-$HOME/.local/state}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}"

# Refuse unexpected storage roots and symlinked components before deleting.
for base in "$HOME" "$state" "$cache"; do
  case "$base" in
    '' | / | . | ..) printf 'Unsafe storage path: %s\n' "$base" >&2; exit 1 ;;
    /*) ;;
    *) printf 'Unsafe storage path: %s\n' "$base" >&2; exit 1 ;;
  esac
done
for base in "$state" "$cache"; do
  case "$HOME/" in
    "$base/"*) printf 'Unsafe storage path: %s\n' "$base" >&2; exit 1 ;;
  esac
done
for path in "$HOME/.local" "$HOME/.local/share" "$HOME/.local/share/quickshell" "$root" \
            "$state" "$state/ukishima" "$cache" "$cache/ukishima"; do
  if [ -L "$path" ]; then
    printf 'Refusing symlinked path: %s\n' "$path" >&2
    exit 1
  fi
done
# Custom XDG paths can have symlinked parents. Check those too, but stop at HOME
# so a symlinked HOME is not newly rejected.
for target in "$state" "$cache"; do
  parent=$(dirname -- "$target")
  while [ "$parent" != / ] && [ "$parent" != "$HOME" ]; do
    if [ -L "$parent" ]; then
      printf 'Refusing symlinked path: %s\n' "$parent" >&2
      exit 1
    fi
    parent=$(dirname -- "$parent")
  done
done

if [ -e "$root" ]; then
  if [ ! -f "$root/shell.qml" ] || [ ! -d "$root/components" ] || \
     [ ! -f "$root/scripts/check-deps.sh" ]; then
    printf 'Refusing to remove an unrecognized installation: %s\n' "$root" >&2
    exit 1
  fi

  # A normal install is a clean official master checkout. Anything else may be
  # a development checkout with work worth keeping.
  if [ -e "$root/.git" ]; then
    command -v git >/dev/null 2>&1 || {
      printf 'Refusing to remove a git checkout without git available to verify it: %s\n' "$root" >&2
      exit 1
    }
    remote=$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)
    branch=$(git -C "$root" branch --show-current 2>/dev/null || true)
    upstream=$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
    changes=$(git -C "$root" status --porcelain 2>/dev/null || printf x)
    ahead=$(git -C "$root" rev-list --count '@{upstream}..HEAD' 2>/dev/null || printf x)
    eligible=1
    case "$remote" in
      https://github.com/amanhex/Ukishima.git | https://github.com/amanhex/Ukishima | git@github.com:amanhex/Ukishima.git) ;;
      *) eligible=0 ;;
    esac
    [ "$branch" = master ] || eligible=0
    [ "$upstream" = origin/master ] || eligible=0
    [ -z "$changes" ] || eligible=0
    [ "$ahead" = 0 ] || eligible=0
    if [ "$eligible" -ne 1 ]; then
      printf 'Refusing to remove a development or modified checkout: %s\n' "$root" >&2
      printf 'Commit, stash, or move your work first, or remove the directory manually.\n' >&2
      exit 1
    fi
  fi
else
  printf 'Ukishima application files are not installed; checking application data.\n'
fi

if (( keep_data )); then
  printf 'Remove Ukishima application files, keeping settings and caches? [y/N]: '
else
  printf 'Remove Ukishima, including its settings, state and caches? [y/N]: '
fi
answer=''
IFS= read -r answer </dev/tty 2>/dev/null || answer=''
case "$answer" in
  y | Y | yes | YES) ;;
  *) printf 'Cancelled.\n'; exit 0 ;;
esac

rm -rf -- "$root"

if (( ! keep_data )); then
  rm -rf -- "$state/ukishima" "$cache/ukishima"

  # Legacy wallpaper state stored directly under XDG_STATE_HOME. Remove only
  # the exact files Ukishima wrote; never follow a symlink out of the state dir.
  for file in \
    "$state/ukishima-wallpaper-dir" \
    "$state/ukishima-wallpaper" \
    "$state/ukishima-wallpaper-map" \
    "$state/ukishima-wallpaper-bag" \
    "$state/ukishima-wallpaper-fit" \
    "$state/ukishima-wallpaper-still.png"; do
    [ -f "$file" ] && [ ! -L "$file" ] && rm -f -- "$file"
  done

  # Generated stills for individual monitors. The name is Ukishima-owned and
  # the entry must be a regular file, not a symlink to something else.
  shopt -s nullglob
  for still in "$state"/ukishima-wallpaper-still-*.png; do
    [ -f "$still" ] && [ ! -L "$still" ] && rm -f -- "$still"
  done
  shopt -u nullglob
fi

printf '\nUkishima uninstalled successfully.\n'
if (( keep_data )); then
  printf 'Settings and caches were preserved.\n'
else
  printf 'Ukishima settings, state and caches were removed.\n'
fi
printf 'Your original wallpapers, applications and compositor configuration were not changed.\n'
printf 'Remove any Ukishima startup commands or keybindings from your compositor config.\n'
