#!/usr/bin/env bash
set -eu

REPO="https://github.com/amanhex/Ukishima.git"
: "${HOME:?HOME is not set}"
ROOT="$HOME/.local/share/quickshell/ukishima"
PARENT=$(dirname -- "$ROOT")
STAGE=""

cleanup() {
  if [ -n "$STAGE" ]; then rm -rf -- "$STAGE"; fi
}
trap cleanup EXIT

printf 'Ukishima Installer\n\n'

if [ -L "$ROOT" ]; then
  printf 'Installation path is a symlink; leaving it untouched.\n' >&2
  exit 1
fi

if [ -e "$ROOT/.git" ]; then
  remote=$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || true)
  branch=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
  upstream=$(git -C "$ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
  changes=$(git -C "$ROOT" status --porcelain 2>/dev/null || printf x)
  ahead=$(git -C "$ROOT" rev-list --count '@{upstream}..HEAD' 2>/dev/null || printf x)
  case "$remote" in
    "$REPO" | "${REPO%.git}" | git@github.com:amanhex/Ukishima.git) official=1 ;;
    *) official=0 ;;
  esac

  if [ "$official" -ne 1 ] || [ "$branch" != master ] || [ "$upstream" != origin/master ] || [ -n "$changes" ] || [ "$ahead" != 0 ]; then
    printf 'Existing installation is not a clean official master checkout; leaving it untouched.\n'
  else
    printf 'Ukishima is already installed. Update it? [y/N]: '
    answer=""
    if IFS= read -r answer </dev/tty 2>/dev/null; then
      case "$answer" in
        y | Y | yes | YES)
          printf 'Updating...\n'
          if ! git -C "$ROOT" pull --ff-only --quiet; then
            printf 'Update failed. Check your connection or review the checkout, then retry.\n' >&2
            exit 1
          fi
          printf '✓ Ukishima updated\n'
          ;;
        *) printf 'Existing installation kept.\n' ;;
      esac
    else
      printf 'No terminal available; existing installation kept.\n'
    fi
  fi
elif [ -e "$ROOT" ]; then
  printf 'Installation path already exists; leaving it untouched.\n'
else
  command -v git >/dev/null 2>&1 || {
    printf 'git is required to install Ukishima.\n' >&2
    exit 1
  }
  mkdir -p "$PARENT"
  STAGE=$(mktemp -d "$PARENT/.ukishima-install.XXXXXX") || {
    printf 'Could not prepare the installation directory. Check its permissions and retry.\n' >&2
    exit 1
  }
  printf 'Cloning into %s...\n' "$ROOT"
  if ! git clone --quiet --depth 1 --branch master "$REPO" "$STAGE/repo"; then
    printf 'Download failed. Check your connection and retry.\n' >&2
    exit 1
  fi
  for file in shell.qml launch.sh dependencies.json scripts/wm.sh scripts/check-deps.sh; do
    if [ ! -f "$STAGE/repo/$file" ]; then
      printf 'Downloaded files are incomplete (%s missing); nothing was installed.\n' "$file" >&2
      exit 1
    fi
  done
  if [ ! -d "$STAGE/repo/components" ]; then
    printf 'Downloaded files are incomplete (components/ missing); nothing was installed.\n' >&2
    exit 1
  fi
  if [ ! -x "$STAGE/repo/scripts/check-deps.sh" ]; then
    printf 'Downloaded files are incomplete (check-deps.sh is not executable); nothing was installed.\n' >&2
    exit 1
  fi
  if ! mv -T -- "$STAGE/repo" "$ROOT"; then
    printf 'Could not place Ukishima in %s; nothing was installed.\n' "$ROOT" >&2
    exit 1
  fi
fi

if [ ! -f "$ROOT/scripts/wm.sh" ] || [ ! -x "$ROOT/scripts/check-deps.sh" ]; then
  printf 'Ukishima files are incomplete at %s; check the download and retry.\n' "$ROOT" >&2
  exit 1
fi

. "$ROOT/scripts/wm.sh"

printf '\nChecking dependencies...\n'
dep_rc=0
UKISHIMA_WM="$UKISHIMA_WM" "$ROOT/scripts/check-deps.sh" --install || dep_rc=$?
if [ "$dep_rc" -ne 0 ]; then
  if [ "$dep_rc" -eq 1 ]; then
    printf '\nRequired dependencies are missing; install them and run the installer again.\n' >&2
  else
    printf '\nCould not check dependencies; fix the error above and run the installer again.\n' >&2
  fi
  exit 1
fi

printf '\n✓ Ukishima installed\n✓ %s detected\n\nAdd this to your compositor config:\n' "$UKISHIMA_WM"
case "$UKISHIMA_WM" in
  hyprland) printf '  exec-once = %s/launch.sh\n' "$ROOT" ;;
  niri) printf '  spawn-at-startup "sh" "-c" "exec %s/launch.sh"\n' "$ROOT" ;;
  *) printf '  %s/launch.sh\n  (compositor not recognized; set UKISHIMA_WM=hyprland|niri if needed)\n' "$ROOT" ;;
esac
