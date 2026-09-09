# 浮島 Ukishima

> A dynamic-island Quickshell shell for Hyprland.

Ukishima (浮島, *"floating island"*) is a widget layer for Hyprland built around a single morphing pill at the top of every monitor. Collapsed it is a thin warm-vermillion strip; hover it and it expands in place into a control centre — workspace dots, clock, media, system readouts — and every module grows its own surface out of the pill itself. Nothing ever pops up as a separate panel.

The project is fully self-contained. It makes no changes to existing Hyprland config files.

## Preview

<p align="center">
<a href="https://youtu.be/5aSVFX3FqvM">
  <img src="https://img.youtube.com/vi/5aSVFX3FqvM/maxresdefault.jpg" width="80%" alt="Ukishima demo on YouTube">
</a>
</p>

## Credits

Ukishima is built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei). The pill concept, the morphing-surface architecture and most of the original shell codebase come from there; this project extends, reworks and rebrands it. All credit for the base code goes to the original author. Big thanks to everyone who has tested and given feedback along the way.

## Features

- **Dynamic island** — one morphing pill per monitor, expanding in place with a bead cursor and smooth morph animations.
- **Surfaces** grown from the pill: launcher, weather, calendar, media, mixer, wallpaper strip + online search, screen recorder, clipboard history, wifi, bluetooth, battery, power menu, system monitor (with a speed test), notification centre, minimized-window stash, OSD, toasts, and a settings hub (appearance → display, theme, font, interface, update).
- **Wallpaper system** — `awww` backend with a shuffled bag, per-monitor assignment, animated transitions, live wallpapers (`mpvpaper`), a per-wallpaper fit control (Cover / Contain / Stretch / Center) that rescales the screen in place, and a live palette that retints the whole UI plus the terminal on every change; an online **wallhaven** browse/search with pagination, Hot / Latest / Top / Random / Top Liked sorting, and memory-only thumbnails (nothing cached to disk).
- **Screen recorder** — `gpu-screen-recorder` with slurp window/region picking, countdown, quality presets, audio, and a recent-clips filmstrip.
- **Media** — a Dynamic-Glacier-style player card with album art (falling back to the playing app's icon when there is no cover), pick-a-source switching, and live wifi speeds plus the connected Bluetooth device and its battery; expand it into the full pill or the media surface. Smaller touches: device-type icons, "Not connected" states, expand-until-dismissed.
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
| `kitty` | live terminal palette reload via `kitty @ set-colors` (add `allow_remote_control yes` to kitty.conf and `include ~/.cache/ukishima/kitty-colors` for persistence) |
| `fastfetch` | recoloured system readout (needs `~/.config/fastfetch/config.jsonc.in`) |
| `hypridle` | idle / DPMS lock integration alongside the built-in keep-awake |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

This clones the project to `~/.local/share/quickshell/ukishima`, checks dependencies, and prints the keybinds and auto-launch line to add to your Hyprland config. If already installed, it pulls the latest changes instead. The updater inside the settings hub tells you when a new version is waiting.

The auto-launch line points at [`launch.sh`](#lower-memory), which starts the shell with jemalloc decay settings so memory stays close to the live working set instead of holding the session peak.

**Already installed?** Pull updates from the **Update** sub-surface inside the pill's settings (Appearance → Update), run the same command above, or pull manually:

```bash
cd ~/.local/share/quickshell/ukishima && git pull
```

If you were running the shell from an older autostart line, switch it to [`launch.sh`](#lower-memory) inside your install (anywhere the project lives).

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
```

Removes the program files, all state (`~/.local/state/ukishima*`) and every disk cache (all under `~/.cache/ukishima`, plus legacy scattered dirs), and stops any running instance.

You still need to remove the `exec-once` auto-launch line and the SUPER keybinds you added to your Hyprland config, and uninstall any dependencies you installed only for Ukishima (see [Dependencies](#dependencies)).

## Lower memory

Ukishima launches through `launch.sh`, which sets jemalloc's `MALLOC_CONF` (`background_thread:true,dirty_decay_ms:100,muzzy_decay_ms:100`) before starting Quickshell. Quickshell links jemalloc; without the decay settings the allocator **retains freed pages at the session's peak**, so resident memory climbs toward whatever the busiest moment was and stays there. With decay on, unused pages are returned to the OS and RSS sits near the live working set (~250 MB).

`launch.sh` resolves its own location, so it works from any install path. If the `quickshell` binary is shipped under a different name (`qs`), it falls back to that. Running `quickshell --config …` directly still works, but skips the memory tuning — so prefer launching (and auto-launching) through `launch.sh`.

If you installed before `launch.sh` existed and your Hyprland autostart still runs `quickshell --config …`, point that line at launch.sh inside your install — e.g. `exec-once = ~/wherever/Ukishima/launch.sh`.

## Launch

```bash
/path/to/your/ukishima/launch.sh
```

`launch.sh` is the launch script at the top of your install — run it from wherever you cloned the project. To auto-launch, add it to your Hyprland config (examples use the default install path):

**hyprlang (.conf)**

```conf
exec-once = ~/.local/share/quickshell/ukishima/launch.sh
```

**Lua**

```lua
hl.exec_cmd("~/.local/share/quickshell/ukishima/launch.sh")
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

Available IPC handlers: `launcher`, `wallpaper`, `clipboard`, `mixer`, `calendar`, `media`, `power`, `link`, `battery`, `sysmon`/`system`, `recorder`/`screenrec`/`record`, `quickRecord`, `gameMode`, `peek`, `hide`, `unloadAll`, `page`, `minimizeWindow`, `restoreWindow`. `unloadAll` drops every closed surface on every monitor immediately (the open one is left alone). With Memory saver on, closed surfaces otherwise unload themselves after a per-surface idle tier (heavy wallpaper/mixer ~30s, everything else ~60s); off, they stay resident until `unloadAll`. The `page` handler takes the monitor first (empty = focused) and the surface name second — `qs -c ukishima ipc call ukishima page "" wifi`.

## State & cache

- state: `$XDG_STATE_HOME/ukishima` (default `~/.local/state/ukishima`) — flags, events, gamemode snapshot; wallpaper selection lives in sibling files `~/.local/state/ukishima-wallpaper*`
- cache: `$XDG_CACHE_HOME/ukishima` (default `~/.cache/ukishima`) — every disk cache under one root: palette JSON, screen-recording thumbs (`rec-thumbs/`), wallpaper previews (`wp-thumbs/`), clipboard previews (`cliphist-thumbs/`), weather forecast + location (`weather/`)
