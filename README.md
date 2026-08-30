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
- **Surfaces** grown from the pill: launcher, weather, calendar, media, mixer, wallpaper strip + online search, screen recorder, clipboard history, wifi, bluetooth, battery, power menu, system monitor (with a speed test), notification centre, minimized-window stash, OSD, toasts, and a settings hub (appearance → display, theme, font, interface, update).
- **Wallpaper system** — `awww` backend with a shuffled bag, per-monitor assignment, animated transitions, live wallpapers (`mpvpaper`), a per-wallpaper fit control (Cover / Contain / Stretch / Center) that rescales the screen in place, and a live palette that retints the whole UI plus the terminal on every change; an online **wallhaven** browse/search with pagination, Hot / Latest / Top / Random / Top Liked sorting, and memory-only thumbnails (nothing cached to disk).
- **Screen recorder** — `gpu-screen-recorder` with slurp window/region picking, countdown, quality presets, audio, and a recent-clips filmstrip.
- **Weather** — Open-Meteo current conditions, hourly and five-day forecast in a dedicated surface, with an editable location (falls back to IP auto-detection).
- **Extras** — night light (hyprsunset), clipboard manager (cliphist), music visualiser (cava), game mode, quick-record keybind, keep-awake, and an in-app updater that pulls the latest release from GitHub.

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
| `upower` | battery status and charge reporting |
| `bluez` (`bluetoothctl`) | bluetooth surface |
| `jq` | JSON parsing in the helper scripts |
| `magick` (ImageMagick) | wallpaper thumbnails and palette |
| `awww` + `awww-daemon` | wallpaper backend |
| `ffmpeg` | video-wallpaper still extraction |
| `nmcli` (NetworkManager) | wifi surface |
| `brightnessctl` or `light` | backlight control |
| `cava` | music visualiser |
| `cliphist` + `wl-clipboard` | clipboard history |
| `slurp` | window/region picker for screen recording |
| `hyprsunset` | night light |

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
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

This clones the project to `~/.local/share/quickshell/ukishima`, checks dependencies, and prints the keybinds and auto-launch line to add to your Hyprland config. If already installed, it pulls the latest changes instead.

**Already installed?** Pull updates from the **Update** sub-surface inside the pill's settings (Appearance → Update), run the same command above, or pull manually:

```bash
cd ~/.local/share/quickshell/ukishima && git pull
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
```

Removes the program files, all state (`~/.local/state/ukishima*`) and all caches (`~/.cache/ukishima*`, `~/.cache/cliphist-thumbs`, `~/.cache/pill`), and stops any running instance.

You still need to remove the `exec-once` auto-launch line and the SUPER keybinds you added to your Hyprland config, and uninstall any dependencies you installed only for Ukishima (see [Dependencies](#dependencies)).

## Launch

```bash
quickshell --config "$HOME/.local/share/quickshell/ukishima"
```

To auto-launch, add to your Hyprland config:

**hyprlang (.conf)**

```conf
exec-once = quickshell --config ~/.local/share/quickshell/ukishima
```

**Lua**

```lua
hl.exec_cmd("quickshell --config ~/.local/share/quickshell/ukishima")
```

## Keybinds (IPC)

Every surface and action is exposed over quickshell IPC (target `ukishima`). The `""` argument is the monitor — empty means "focused monitor". Bind them in your Hyprland config.

**hyprlang (.conf)**

```
bind = SUPER, SHIFT+W, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper ""
bind = SUPER, SHIFT+V, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard ""
bind = SUPER, slash,   exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
```

**Lua**

```lua
hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper \"\""))
hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard \"\""))
hl.bind(var_mainMod .. " + slash",     hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher \"\""))
```

If you cloned the repo to `~/.config/quickshell/ukishima` instead, replace `qs -p ~/.local/share/quickshell/ukishima` with `qs -c ukishima`.

Available IPC handlers: `launcher`, `wallpaper`, `clipboard`, `mixer`, `calendar`, `media`, `power`, `link`, `battery`, `sysmon`/`system`, `recorder`/`screenrec`/`record`, `quickRecord`, `gameMode`, `peek`, `hide`, `page`, `minimizeWindow`, `restoreWindow`. The `page` handler takes the monitor first (empty = focused) and the surface name second — `qs -c ukishima ipc call ukishima page "" wifi`.

## State & cache

- state: `$XDG_STATE_HOME/ukishima` (default `~/.local/state/ukishima`) — flags, events, gamemode snapshot; wallpaper selection lives in sibling files `~/.local/state/ukishima-wallpaper*`
- cache: `$XDG_CACHE_HOME/ukishima` (default `~/.cache/ukishima`) — palette JSON, rec thumbs; wallpaper previews under `ukishima-wp-thumbs/`, clipboard previews under `cliphist-thumbs/`, weather location under `pill/`
