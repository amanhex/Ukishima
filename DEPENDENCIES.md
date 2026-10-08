# Dependencies

Arch names, unless noted.

## Required

Install these or the shell starts but breaks in places.

| Tool | Package | Used for |
| --- | --- | --- |
| `quickshell` | `quickshell` | the shell runtime itself — nothing starts without it |
| `hyprctl` | `hyprland` | IPC for workspaces, monitors, dispatch and reload |
| `notify-send` | `libnotify` | desktop notifications for the pill and for these dependency reports |
| `jq` | `jq` | JSON parsing in the helper scripts, and for reading the manifest |
| `xdg-open` | `xdg-utils` | opening files and links, including the dependency report page |
| `upower` | `upower` | battery status and charge reporting |
| `bluetoothctl` | `bluez-utils` | the bluetooth surface |
| `nmcli` | `networkmanager` | the wifi surface |
| `brightnessctl` | `brightnessctl` | internal laptop backlight control |
| `hyprsunset` | `hyprsunset` | the night light |
| `awww + awww-daemon` | `awww` | the wallpaper backend (client and daemon) |
| `curl + magick + python3 + ffmpeg` | `curl`, `imagemagick`, `python`, `ffmpeg` | wallpaper download, thumbnails, palette generation and video-wallpaper stills |
| `cava` | `cava` | the music visualiser |
| `cliphist + wl-paste` | `cliphist`, `wl-clipboard` | the clipboard history surface |
| `slurp` | `slurp` | the window/region picker for screen recording |

## Optional

None of these are needed to run the shell. They add features, so install the
ones you actually want.

| Package | Adds |
| --- | --- |
| `gpu-screen-recorder` | the screen-recording backend — recording is disabled without it |
| `mpvpaper` | animated / video wallpapers |
| `matugen` | Material base16 palettes (always-dark terminal theme, dynamic wallpaper palette) |
| `ddcutil` | monitor brightness via DDC (external display faders) |
| `kdialog` / `zenity` | the native folder picker for the record output directory |
| `power-profiles-daemon` | the power-profile picker on the battery hover — the row shows "Not installed" without it, and it isn't needed on desktops |
| `hyprlock` | the lock backend the shell prefers — without it the lock falls back to the Quickshell lockscreen, which has its own background, blur, avatar and indicator settings |
| `grim` | all screenshot-studio captures, plus the capture behind the lock's backdrop — without it that backdrop falls back to the wallpaper |
| `hyprpicker` | the color-picker mode of the screenshot studio (copies the hex itself) |
| `kitty` | live terminal palette reload via `kitty @ set-colors` (needs `allow_remote_control yes`, and `include ~/.cache/ukishima/kitty-colors` for persistence) |
| `ghostty` | live terminal palette reload over D-Bus |
| `fastfetch` | the recoloured system readout (needs `~/.config/fastfetch/config.jsonc.in`) |
| `hypridle` | idle / DPMS lock integration alongside the built-in keep-awake |
