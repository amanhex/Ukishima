#!/usr/bin/env bash
set -eu

REPO="https://github.com/amanhex/Ukishima.git"
INSTALL_ROOT="${HOME}/.local/share/quickshell/ukishima"

if [ -d "$INSTALL_ROOT" ]; then
  printf '\033[1;33mUkishima is already installed at %s\033[0m\n' "$INSTALL_ROOT"
  printf 'Pulling latest changes...\n'
  git -C "$INSTALL_ROOT" pull --ff-only || printf '\033[1;33mCould not pull — try removing %s and reinstalling.\033[0m\n' "$INSTALL_ROOT"
else
  printf 'Cloning Ukishima...\n'
  git clone --depth 1 "$REPO" "$INSTALL_ROOT"
fi

warn() { printf '  \033[1;33m%s\033[0m\n' "$*"; }

printf '\nChecking dependencies...\n'

missing=0
check() {
  if ! command -v "$1" >/dev/null 2>&1; then
    missing=1
    warn "missing: $2 ($1)"
  fi
}

check quickshell   "shell runtime"
check hyprctl      "Hyprland IPC"
check upower       "battery status"
check bluetoothctl "bluetooth surface"
check jq           "JSON parsing"
check notify-send  "desktop notifications"
check curl         "weather + wallpaper"
check python3      "palette generation"
check magick       "wallpaper thumbs"
check awww         "wallpaper daemon"
check awww-daemon  "wallpaper daemon"
check ffmpeg       "video wallpaper"
check nmcli        "wifi surface"
check brightnessctl "backlight control"
check cava         "music visualiser"
check cliphist     "clipboard history"
check wl-paste     "clipboard history"
check slurp        "screen recording picker"
check hyprsunset   "night light"
check xdg-open     "open files"

for b in gpu-screen-recorder mpvpaper matugen ddcutil kdialog zenity; do
  command -v "$b" >/dev/null 2>&1 || warn "optional: $b"
done

IPC_PREFIX="qs -p $INSTALL_ROOT"

printf '
\033[1;32mUkishima installed!\033[0m

Add these to your Hyprland config:

  Auto-launch:
    exec-once = quickshell --config %s

  Keybinds (hyprlang):
    bind = SUPER, SHIFT+W, exec, %s ipc call ukishima wallpaper ""
    bind = SUPER, SHIFT+V, exec, %s ipc call ukishima clipboard ""
    bind = SUPER, slash,   exec, %s ipc call ukishima launcher ""

  Keybinds (lua):
    hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("%s ipc call ukishima wallpaper \\\"\\\""))
    hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("%s ipc call ukishima clipboard \\\"\\\""))
    hl.bind(var_mainMod .. " + slash",     hl.dsp.exec_cmd("%s ipc call ukishima launcher \\\"\\\""))

  Launch manually:
    quickshell --config %s

  State: ~/.local/state/ukishima
  Cache: ~/.cache/ukishima
' "$INSTALL_ROOT" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$IPC_PREFIX" "$INSTALL_ROOT"

[ "$missing" -eq 0 ] || printf '\n\033[1;31mSome core dependencies are missing — install them for full functionality.\033[0m\n' >&2
