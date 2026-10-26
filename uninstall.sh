#!/usr/bin/env bash
set -eu

[[ $# -eq 0 ]] || { printf 'Usage: %s\n' "$0" >&2; exit 2; }

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

printf 'Remove Ukishima, including its settings, state and caches? [y/N]: '
answer=''
IFS= read -r answer </dev/tty 2>/dev/null || answer=''
case "$answer" in
  y | Y | yes | YES) ;;
  *) printf 'Cancelled.\n'; exit 0 ;;
esac

stop_ukishima() {
  local proc pid exe arg i config_path
  local -a argv app_pids=()
  for proc in /proc/[0-9]*; do
    pid=${proc##*/}
    [[ "$pid" != "$$" && -r "$proc/cmdline" ]] || continue
    exe=$(basename -- "$(readlink -- "$proc/exe" 2>/dev/null || true)")
    [[ "$exe" == quickshell || "$exe" == qs ]] || continue
    argv=()
    mapfile -d '' -t argv < "$proc/cmdline" 2>/dev/null || continue
    config_path=""
    for ((i = 0; i < ${#argv[@]}; i++)); do
      arg=${argv[i]}
      case "$arg" in
        --path | -p | --config | --config-path)
          if (( i + 1 < ${#argv[@]} )); then
            config_path=${argv[i + 1]}
          fi
          ;;
        --path=* | --config=*)
          config_path=${arg#*=}
          ;;
      esac
    done
    case "$config_path" in
      "$root/lockscreen/shell.qml")
        printf 'The Ukishima lockscreen is active (pid %s); finish unlocking before uninstalling. No files were removed.\n' "$pid" >&2
        return 1
        ;;
      "$root" | "$root/shell.qml") app_pids+=("$pid") ;;
      "$root"/*)
        printf 'A Ukishima Quickshell process has an unrecognized config path (pid %s); no files were removed.\n' "$pid" >&2
        return 1
        ;;
    esac
  done

  for pid in "${app_pids[@]}"; do
    kill -TERM "$pid" 2>/dev/null || {
      printf 'Could not stop the running Ukishima instance (pid %s); no files were removed.\n' "$pid" >&2
      return 1
    }
    for _ in {1..30}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
      printf 'The Ukishima instance (pid %s) did not stop; no files were removed.\n' "$pid" >&2
      return 1
    fi
  done
}

if ! stop_ukishima; then
  exit 1
fi

rm -rf -- "$root"
if [ -e "$root" ] || [ -L "$root" ]; then
  printf 'Could not remove Ukishima application files: %s\n' "$root" >&2
  exit 1
fi

rm -rf -- "$state/ukishima" "$cache/ukishima"

# Remove only known legacy files outside the Ukishima state directory. The
# calendar file is the sole Ukishima-owned file in the shared legacy pill dir.
# rm -f unlinks a symlink itself, not its target.
shopt -s nullglob
legacy_files=(
  "$state/ukishima-wallpaper-dir" \
  "$state/ukishima-wallpaper" \
  "$state/ukishima-wallpaper-map" \
  "$state/ukishima-wallpaper-bag" \
  "$state/ukishima-wallpaper-fit" \
  "$state/ukishima-wallpaper-still.png"
  "$state/pill/events.json"
  "$state"/ukishima-wallpaper-still-*.png
)
for file in "${legacy_files[@]}"; do
  if [ -L "$file" ] || [ -f "$file" ]; then
    rm -f -- "$file"
  fi
  if [ -e "$file" ] || [ -L "$file" ]; then
    printf 'Could not remove Ukishima legacy state: %s\n' "$file" >&2
    exit 1
  fi
done
shopt -u nullglob

for target in "$state/ukishima" "$cache/ukishima"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    printf 'Could not remove Ukishima data: %s\n' "$target" >&2
    exit 1
  fi
done

printf '\nUkishima uninstalled successfully.\n'
printf 'Ukishima settings, state and caches were removed.\n'
printf 'Your original wallpapers, applications and compositor configuration were not changed.\n'
printf 'Remove any Ukishima startup commands or keybindings from your compositor config.\n'
