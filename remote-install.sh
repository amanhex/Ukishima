#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/amanhex/Ukishima.git"
: "${HOME:?HOME is not set}"
INSTALL_ROOT="$HOME/.local/share/quickshell/ukishima"
STAGE_DIR=""

cleanup() {
  if [ -n "$STAGE_DIR" ]; then rm -rf -- "$STAGE_DIR"; fi
}
trap cleanup EXIT

printf 'Ukishima Installer\n\n'

if [ -e "$INSTALL_ROOT" ] || [ -L "$INSTALL_ROOT" ]; then
  if [ -L "$INSTALL_ROOT" ]; then
    printf 'Installation path is a symlink; leaving it untouched.\n' >&2
    exit 1
  elif [ -d "$INSTALL_ROOT/.git" ] || [ -f "$INSTALL_ROOT/.git" ]; then
    branch=$(git -C "$INSTALL_ROOT" branch --show-current 2>/dev/null || true)
    remote=$(git -C "$INSTALL_ROOT" remote get-url origin 2>/dev/null || true)
    upstream=$(git -C "$INSTALL_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
    status_ok=1
    if ! changes=$(git -C "$INSTALL_ROOT" status --porcelain 2>/dev/null); then status_ok=0; fi
    case "$remote" in
      https://github.com/amanhex/Ukishima.git|https://github.com/amanhex/Ukishima|git@github.com:amanhex/Ukishima.git) ;;
      *) remote="" ;;
    esac
    if [ "$branch" != master ] || [ -z "$remote" ] || [ "$upstream" != origin/master ] || \
       [ "$status_ok" -ne 1 ] || [ -n "$changes" ]; then
      printf 'Existing installation has local changes or is not a release install; leaving it unchanged.\n'
    else
      printf 'Ukishima is already installed. Update it? [y/N]: '
      answer=""
      if IFS= read -r answer 2>/dev/null </dev/tty; then
        case "$answer" in
          y|Y|yes|YES)
            if git -C "$INSTALL_ROOT" pull --ff-only --quiet 2>/dev/null; then
              printf '✓ Ukishima updated\n'
            else
              printf 'Update failed. Check your connection or retry after reviewing the release checkout.\n' >&2
              exit 1
            fi
            ;;
          *) printf 'Existing installation kept.\n' ;;
        esac
      else
        printf 'No terminal available; existing installation kept.\n'
      fi
    fi
  else
    printf 'Installation path already exists; leaving it untouched.\n'
  fi
else
  command -v git >/dev/null 2>&1 || { printf 'git is required to install Ukishima.\n' >&2; exit 1; }
  install_parent=$(dirname -- "$INSTALL_ROOT")
  mkdir -p "$install_parent"
  STAGE_DIR=$(mktemp -d "$install_parent/.ukishima-install.XXXXXX") || {
    printf 'Could not prepare the installation directory. Check its permissions and retry.\n' >&2
    exit 1
  }
  if ! git clone --quiet --depth 1 --branch master "$REPO" "$STAGE_DIR/repo"; then
    printf 'Download failed. Check your connection and retry.\n' >&2
    exit 1
  fi
  if ! mv -T -- "$STAGE_DIR/repo" "$INSTALL_ROOT"; then
    printf 'Could not place Ukishima in %s; existing files were left untouched.\n' "$INSTALL_ROOT" >&2
    exit 1
  fi
fi

if [ ! -f "$INSTALL_ROOT/scripts/wm.sh" ] || [ ! -x "$INSTALL_ROOT/scripts/check-deps.sh" ]; then
  printf 'Ukishima files are incomplete at %s; check the download and retry.\n' "$INSTALL_ROOT" >&2
  exit 1
fi

. "$INSTALL_ROOT/scripts/wm.sh"

dep_rc=0
dep_output=$(UKISHIMA_WM="$UKISHIMA_WM" "$INSTALL_ROOT/scripts/check-deps.sh" --install 2>&1) || dep_rc=$?
if [ "$dep_rc" -ne 0 ]; then
  printf '%s\n' "$dep_output" >&2
  if [ "$dep_rc" -eq 1 ]; then
    printf 'Required dependencies are missing; install the packages listed above, then run the installer again.\n' >&2
  else
    printf 'Could not check dependencies; fix the error above and rerun the installer.\n' >&2
  fi
  exit 1
fi

printf '✓ Dependencies checked\n✓ %s detected\n\nInstallation complete!\n' "$UKISHIMA_WM"
printf 'Add this startup command to your compositor configuration:\n'
case "$UKISHIMA_WM" in
  hyprland)
    printf '  Hyprland: exec-once = %s/launch.sh\n' "$INSTALL_ROOT"
    ;;
  niri)
    printf '  niri: spawn-at-startup "sh" "-c" "exec %s/launch.sh"\n' "$INSTALL_ROOT"
    ;;
  *)
    printf '  Compositor not recognized. Run %s/launch.sh manually or set UKISHIMA_WM.\n' "$INSTALL_ROOT"
    ;;
esac
