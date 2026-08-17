# 浮島 Ukishima

> A dynamic-island Quickshell shell for Hyprland.

Ukishima (浮島, *"floating island"*) is a widget layer for Hyprland built around a single morphing pill at the top of every monitor. Collapsed it is a thin warm-vermillion strip; hover it and it expands in place into a control centre — workspace dots, clock, media, system readouts — and every module grows its own surface out of the pill itself. Nothing ever pops up as a separate panel.

The project is fully self-contained. It makes no changes to existing Hyprland config files.

## Preview

<p align="center">
<a href="https://youtu.be/Xkld6B5Pke0">
  <img src="https://img.youtube.com/vi/Xkld6B5Pke0/maxresdefault.jpg" width="80%" alt="Ukishima demo on YouTube">
</a>
</p>

See the [full preview gallery](preview/README.md) for all screenshots.

## Credits

Ukishima is built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei). The pill concept, the morphing-surface architecture and most of the original shell codebase come from there; this project extends, reworks and rebrands it. All credit for the base code goes to the original author.

## Features

- **Dynamic island** — one morphing pill per monitor, expanding in place with a bead cursor and smooth morph animations.
- **Surfaces** grown from the pill: launcher, calendar, media, mixer, wallpaper strip + online search, screen recorder, clipboard history, wifi + hotspot, bluetooth, battery, power menu, system monitor, settings (appearance, fonts), OSD and toasts.
- **Wallpaper system** — `awww` backend with a shuffled bag, per-monitor assignment, animated transitions, video wallpapers (`mpvpaper`), and a live palette that retints the whole UI plus the terminal on every change.
- **Screen recorder** — `gpu-screen-recorder` with slurp window/region picking, countdown, quality presets, audio, and a recent-clips filmstrip.
- **Extras** — night light (hyprsunset), clipboard manager (cliphist), music visualiser (cava), game mode, quick-record keybind, keep-awake.

## Requirements

- Linux + Wayland
- **Hyprland** (developed on 0.56.1, works across recent 0.4x/0.5x)
- **Quickshell** 0.3.0+ built with the Hyprland, Wayland and Io QML modules
- Qt6 / QtQuick (ships with Quickshell)

## Dependencies

### Core

| Tool | Used for |
| --- | --- |
| `quickshell` | shell runtime |
| `hyprctl` | Hyprland IPC (workspaces, monitors, dispatch, reload) |
| `jq` | JSON parsing in the helper scripts |
| `notify-send` (libnotify) | desktop notifications |
| `curl` | weather, wallpaper search / downloads |
| `python3` | palette generation (`wallcolors.py`) |
| `magick` (ImageMagick) | wallpaper thumbnails and palette |
| `awww` + `awww-daemon` | wallpaper backend |
| `ffmpeg` | video-wallpaper still extraction |
| `nmcli` (NetworkManager) | wifi + hotspot surface |
| `bluetoothctl` (bluez) | bluetooth surface |
| `brightnessctl` or `light` | backlight control |
| `cava` | music visualiser |
| `cliphist` + `wl-clipboard` | clipboard history |
| `slurp` | window/region picker for screen recording |
| `hyprsunset` | night light |
| `xdg-open` (xdg-utils) | opening record folder / files |
| systemd (user) | keep-awake inhibitor, hyprsunset service |

### Optional, for full functionality

| Package | Adds |
| --- | --- |
| `gpu-screen-recorder` | the screen-recording backend (recording is disabled without it) |
| `mpvpaper` | animated / video wallpapers |
| `matugen` | Material base16 palettes (always-dark terminal theme) |
| `ddcutil` | monitor brightness via DDC (external display faders) |
| `kdialog` / `zenity` | native folder picker for the record output directory |
| `ghostty` | live terminal palette reload over D-Bus |
| `fastfetch` | recoloured system readout (needs `~/.config/fastfetch/config.jsonc.in`) |
| `hypridle` | idle / DPMS lock integration alongside the built-in keep-awake |

## Install

```bash
./install.sh
```

This copies the project to `~/.local/share/quickshell/ukishima` (override with `UKISHIMA_INSTALL_ROOT`), and reports any missing dependencies. The copy is self-contained.

## Uninstall

Remove the install, state and cache folders:

```bash
rm -rf "$HOME/.local/share/quickshell/ukishima"
rm -rf "$HOME/.local/state/ukishima"
rm -rf "$HOME/.cache/ukishima"
```

## Launch

From a clone:

```bash
git clone https://github.com/amanhex/Ukishima ~/.config/quickshell/ukishima
quickshell --config "$HOME/.config/quickshell/ukishima"
```

After an `install.sh` install:

```bash
quickshell --config "$HOME/.local/share/quickshell/ukishima"
```

## Keybinds (IPC)

Every surface and action is exposed over quickshell IPC (target `ukishima`). The `""` argument is the monitor — empty means "focused monitor". Bind them in your Hyprland config.

The IPC path depends on how you installed:

| Install method | IPC prefix |
| --- | --- |
| Clone to `~/.config/quickshell/ukishima` | `qs -c ukishima` |
| `install.sh` (copies to `~/.local/share/quickshell/ukishima`) | `qs -p ~/.local/share/quickshell/ukishima` |

**hyprlang (.conf)** — clone install:

```
bind = SUPER, SHIFT+W, exec, qs -c ukishima ipc call ukishima wallpaper ""
bind = SUPER, SHIFT+V, exec, qs -c ukishima ipc call ukishima clipboard ""
bind = SUPER, slash,   exec, qs -c ukishima ipc call ukishima launcher ""
```

**hyprlang (.conf)** — install.sh:

```
bind = SUPER, SHIFT+W, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper ""
bind = SUPER, SHIFT+V, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard ""
bind = SUPER, slash,   exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
```

**Lua** — clone install:

```lua
hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -c ukishima ipc call ukishima wallpaper \"\""))
hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -c ukishima ipc call ukishima clipboard \"\""))
hl.bind(var_mainMod .. " + slash",     hl.dsp.exec_cmd("qs -c ukishima ipc call ukishima launcher \"\""))
```

**Lua** — install.sh:

```lua
hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper \"\""))
hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard \"\""))
hl.bind(var_mainMod .. " + slash",     hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher \"\""))
```

Available IPC handlers: `launcher`, `wallpaper`, `clipboard`, `mixer`, `calendar`, `media`, `power`, `link`, `battery`, `sysmon`/`system`, `recorder`/`screenrec`/`record`, `quickRecord`, `gameMode`, `peek`, `hide`, `page`, `minimizeWindow`, `restoreWindow`. The `page` handler takes the monitor first (empty = focused) and the surface name second — `qs -c ukishima ipc call ukishima page "" wifi`.

## State & cache

- state: `$XDG_STATE_HOME/ukishima` (default `~/.local/state/ukishima`) — flags, events, wallpaper state, launcher usage
- cache: `$XDG_CACHE_HOME/ukishima` (default `~/.cache/ukishima`) — palette JSON, weather, rec thumbs; wallpaper previews under `ukishima-wp-thumbs/`
