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

printf '\n\033[1;32mUkishima installed!\033[0m\n\n'

cat <<EOF
Add these to your Hyprland or niri config. The installer never edits either.

  Hyprland (hyprlang):
    exec-once = $INSTALL_ROOT/launch.sh
    exec-once = awww-daemon

    bind = SUPER SHIFT, W, exec, $IPC_PREFIX ipc call ukishima wallpaper ""
    bind = SUPER SHIFT, V, exec, $IPC_PREFIX ipc call ukishima clipboard ""
    bind = SUPER, slash, exec, $IPC_PREFIX ipc call ukishima launcher ""
    bind = SUPER, N, exec, $IPC_PREFIX ipc call ukishima notifications ""
    bind = SUPER, L, exec, $INSTALL_ROOT/scripts/lock.sh

  Hyprland (Lua):
    hl.exec_cmd("$INSTALL_ROOT/launch.sh")
    hl.exec_cmd("awww-daemon")

    local uk = "$IPC_PREFIX"
    hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(uk .. " ipc call ukishima wallpaper \\"\\""))
    hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(uk .. " ipc call ukishima clipboard \\"\\""))
    hl.bind(var_mainMod .. " + slash", hl.dsp.exec_cmd(uk .. " ipc call ukishima launcher \\"\\""))
    hl.bind(var_mainMod .. " + N", hl.dsp.exec_cmd(uk .. " ipc call ukishima notifications \\"\\""))
    hl.bind(var_mainMod .. " + L", hl.dsp.exec_cmd("$INSTALL_ROOT/scripts/lock.sh"))

  niri (KDL, ~/.config/niri/config.kdl):
    spawn-at-startup "sh" "-c" "exec $INSTALL_ROOT/launch.sh"
    spawn-at-startup "awww-daemon"

    binds {
        Mod+Shift+W { spawn-sh "$IPC_PREFIX ipc call ukishima wallpaper \\"\\""; }
        Mod+Shift+V { spawn-sh "$IPC_PREFIX ipc call ukishima clipboard \\"\\""; }
        Mod+Slash { spawn-sh "$IPC_PREFIX ipc call ukishima launcher \\"\\""; }
        Mod+N { spawn-sh "$IPC_PREFIX ipc call ukishima notifications \\"\\""; }
        Mod+L { spawn-sh "$INSTALL_ROOT/scripts/lock.sh"; }
    }

  List every surface you can bind:
    $IPC_PREFIX ipc show

  Any other keybind is the same shape — swap the IPC call for the one you want.
  Most calls take a monitor name; pass "" for the focused monitor.

  Lock is a script, not an IPC surface. On Hyprland it uses hyprlock if you
  have it, otherwise its own Quickshell lockscreen; niri uses the built-in
  Quickshell lock. Set the backend under Lock in settings:
    $INSTALL_ROOT/scripts/lock.sh

  Launch manually:
    quickshell --config $INSTALL_ROOT

  State: ~/.local/state/ukishima
  Cache: ~/.cache/ukishima
EOF

[ "$missing" -eq 0 ] || printf '\n\033[1;31mSome core dependencies are missing — install them for full functionality.\033[0m\n' >&2
