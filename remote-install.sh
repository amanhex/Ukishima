#!/usr/bin/env bash
set -eu

REPO="https://github.com/amanhex/Ukishima.git"
INSTALL_ROOT="${HOME}/.local/share/quickshell/ukishima"

if [ -d "$INSTALL_ROOT" ]; then
  printf '\033[1;33mUkishima is already installed at %s\033[0m\n' "$INSTALL_ROOT"
  printf 'Pulling latest changes...\n'
  git -C "$INSTALL_ROOT" pull --ff-only origin master || printf '\033[1;33mCould not pull — try removing %s and reinstalling.\033[0m\n' "$INSTALL_ROOT"
else
  printf 'Cloning Ukishima...\n'
  git clone --depth 1 --branch master "$REPO" "$INSTALL_ROOT"
fi

warn() { printf '  \033[1;33m%s\033[0m\n' "$*"; }

printf '\nChecking dependencies...\n'

# The dependency list lives in dependencies.json, which the shell's post-update
# report and DEPENDENCIES.md also read, so an update that adds a requirement
# cannot leave the installer still describing the old set. This runs after the
# clone/pull above, so it always reports against the manifest just fetched.
#
# The `|| dep_rc=$?` form is deliberate: it keeps `set -e` from killing the
# installer on a *missing dependency*, which is a reportable state, not a
# failure of the installer.
missing=0
dep_rc=0
"$INSTALL_ROOT/scripts/check-deps.sh" --install || dep_rc=$?
case "$dep_rc" in
  0) ;;
  1) missing=1 ;;
  *)
    missing=1
    warn "could not read dependencies.json — the full list was not checked"
    ;;
esac

IPC_PREFIX="qs -p $INSTALL_ROOT"

printf '
\033[1;32mUkishima installed!\033[0m

Add these to your Hyprland config:

  Auto-launch (lower-memory launcher):
    exec-once = %s/launch.sh

  Wallpaper daemon — start it here rather than letting the shell start it, so
  it is already up when the shell restores your wallpaper (no ~1s delay):
    exec-once = awww-daemon

  Keybinds (hyprlang):
    bind = SUPER, SHIFT+W, exec, %s ipc call ukishima wallpaper ""
    bind = SUPER, SHIFT+V, exec, %s ipc call ukishima clipboard ""
    bind = SUPER, slash,   exec, %s ipc call ukishima launcher ""
    bind = SUPER, L,       exec, %s/scripts/lock.sh
    bind = , Print,        exec, %s/scripts/shot.sh screen
    bind = SHIFT, Print,   exec, %s/scripts/shot.sh region

  Keybinds (lua):
    hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("%s ipc call ukishima wallpaper \\\"\\\""))
    hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("%s ipc call ukishima clipboard \\\"\\\""))
    hl.bind(var_mainMod .. " + slash",     hl.dsp.exec_cmd("%s ipc call ukishima launcher \\\"\\\""))
    hl.bind(var_mainMod .. " + L",         hl.dsp.exec_cmd("%s/scripts/lock.sh"))
    hl.bind("Print",                       hl.dsp.exec_cmd("%s/scripts/shot.sh screen"))
    hl.bind("SHIFT + Print",               hl.dsp.exec_cmd("%s/scripts/shot.sh region"))

  Lock is a script, not an IPC surface. It uses hyprlock if you have it,
  otherwise its own Quickshell lockscreen — set the backend under Lock in
  settings once it is running.

  Launch manually:
    quickshell --config %s

  State: ~/.local/state/ukishima
  Cache: ~/.cache/ukishima
' "$INSTALL_ROOT" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$INSTALL_ROOT" "$INSTALL_ROOT" "$INSTALL_ROOT" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$INSTALL_ROOT" "$INSTALL_ROOT" "$INSTALL_ROOT"

[ "$missing" -eq 0 ] || printf '\n\033[1;31mSome core dependencies are missing — install them for full functionality.\033[0m\n' >&2
