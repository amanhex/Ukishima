# 浮島 Ukishima

> A dynamic-island Quickshell shell for Hyprland and niri.

Ukishima (浮島, *"floating island"*) is a widget layer for Hyprland and niri built around a morphing pill at the top of every monitor that expands in place into a control centre, plus a floating macOS-style 泊 dock at the bottom edge for pinned and running apps. Fully self-contained — it makes no changes to your existing compositor configuration.

## Preview

<p align="center">
<a href="https://ukishima.uklab.workers.dev/">
  <img src="assets/ukishima-readme-banner.png" width="100%" alt="Ukishima">
</a>
</p>

Explore the animated showcase, features and settings on the [Ukishima website](https://ukishima.uklab.workers.dev/).

## Features

- **Dynamic island** — one morphing pill per monitor; every module grows its own surface out of it, in place. Right-click walks the pill: collapse, media, timer, then up to two more surfaces you pick under **Settings → Interface → Right-click**.
- **泊 Dock** — pinned and running apps with hover magnification and multi-window previews (no cursor warp), auto-hide, and its own theme (Light / Dark / Dynamic / Manual) and glass.
- **Surfaces** — launcher, weather, calendar, media, mixer, wallpaper strip + Wallhaven search, screen recorder, clipboard, Wi-Fi, Bluetooth, battery, power menu, system monitor, notifications, OSD, toasts, scratchpad, settings.
- **Wallpapers** — shuffled `awww` bag, live `mpvpaper` videos, per-wallpaper fit, and a palette that retints the UI.
- **Compositor-aware** — supports both Hyprland and niri, with compositor-specific features enabled where available.
- **Extras** — night light (Hyprland), game mode, keep-awake, in-app updater.

## Requirements

- Linux + Wayland, **Hyprland** or **niri**
- **Quickshell** 0.3.0+ 
- Additional CLI tools — the installer checks them; see [Dependencies](DEPENDENCIES.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

Clones Ukishima to `~/.local/share/quickshell/ukishima`, checks dependencies, and detects your compositor. The installer provides the relevant startup instructions without modifying your configuration.

## Use

### Launch / Auto-launch

Launch Ukishima through `launch.sh` — it applies jemalloc decay settings to help keep memory usage closer to the live working set.

**Hyprland** (`~/.config/hypr/hyprland.conf`):

```ini
exec-once = ~/.local/share/quickshell/ukishima/launch.sh
```

For Hyprland Lua configurations:

```lua
hl.exec_cmd("~/.local/share/quickshell/ukishima/launch.sh")
```

**niri** (`~/.config/niri/config.kdl`):

```kdl
spawn-at-startup "sh" "-c" "exec $HOME/.local/share/quickshell/ukishima/launch.sh"
```

### Wallpaper daemon

Start `awww-daemon` alongside Ukishima so wallpapers can be applied without waiting for the daemon to start.

Hyprland:

```ini
exec-once = awww-daemon
```

niri:

```kdl
spawn-at-startup "awww-daemon"
```

### Keybinds

Ukishima doesn't modify your compositor's keybindings. You can assign shortcuts to whichever surfaces you use most.

For example, opening the wallpaper surface:

```bash
qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper ""
```

For compositor-specific keybinding examples, including **Hyprland, Hyprland Lua, and niri**, see:

**[Keybindings & IPC Guide](docs/KEYBINDINGS.md)**

The guide also includes the full list of available IPC commands.

### Lock

Ukishima provides its own lockscreen and supports external lockers.

- **Hyprland** — Hyprlock or Quickshell lockscreen
- **niri** — swaylock or Quickshell lockscreen

The lock script is:

```bash
~/.local/share/quickshell/ukishima/scripts/lock.sh
```

Choose your preferred backend under **Settings → Lock**. You can bind the script to your preferred keyboard shortcut using the [keybindings guide](docs/KEYBINDINGS.md).

## Update

Ukishima includes a built-in updater.

Open **Settings → Update**, click **Check for Updates**, and select **Update Ukishima** when a new version is available.

Updates are applied safely without discarding local modifications. Modified or development checkouts can be updated manually.

## Uninstall

To completely remove Ukishima, run:

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
```

This removes Ukishima's application files, settings, state, caches, and generated wallpaper files.

After uninstalling, remove any Ukishima startup commands or keybindings from your compositor configuration.

## Credits

Built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei) — the pill concept, the morphing-surface architecture and most of the original codebase. All credit for the base code goes to the original author.