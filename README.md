# 浮島 Ukishima

> A dynamic-island Quickshell shell for Hyprland.

Ukishima (浮島, *"floating island"*) is a widget layer for Hyprland built around a morphing pill at the top of every monitor that expands in place into a control centre, plus a floating macOS-style 泊 dock at the bottom edge for pinned and running apps. Fully self-contained — it makes no changes to your existing Hyprland config.

## Preview

<p align="center">
<a href="https://youtu.be/5aSVFX3FqvM">
  <img src="https://img.youtube.com/vi/5aSVFX3FqvM/maxresdefault.jpg" width="80%" alt="Ukishima demo on YouTube">
</a>
</p>

## Features

- **Dynamic island** — one morphing pill per monitor; every module grows its own surface out of it, in place.
- **泊 Dock** — pinned and running apps with hover magnification and multi-window previews (no cursor warp), auto-hide, and its own theme (Light / Dark / Dynamic / Manual) and glass.
- **Surfaces** — launcher, weather, calendar, media, mixer, wallpaper strip + wallhaven search, screen recorder, clipboard, wifi, bluetooth, battery, power menu, system monitor, notifications, OSD, toasts, settings.
- **Wallpapers** — shuffled `awww` bag, live `mpvpaper` videos, per-wallpaper fit, and a palette that retints the UI.
- **Extras** — night light, game mode, keep-awake, in-app updater.

## Requirements

- Linux + Wayland, **Hyprland** (recent 0.4x/0.5x)
- **Quickshell** 0.3.0+ (Hyprland, Wayland and Io modules)
- CLI tools — the installer checks them; see [DEPENDENCIES](DEPENDENCIES.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

Clones to `~/.local/share/quickshell/ukishima`, checks dependencies, and prints the keybinds and auto-launch line to add. Update it the same way — or from the **Update** surface inside the settings — whenever you want the latest.

## Use

- **Launch / auto-launch** through **`launch.sh`** — it adds jemalloc decay settings so memory stays near the live working set instead of the session peak (~250 MB RSS):

  ```conf
  exec-once = ~/.local/share/quickshell/ukishima/launch.sh
  ```

  (Lua: `hl.exec_cmd("~/.local/share/quickshell/ukishima/launch.sh")`)

- **Keybinds** — every surface answers over quickshell IPC (target `ukishima`; empty monitor arg = focused):

  ```conf
  bind = SUPER, SHIFT+W, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper ""
  bind = SUPER, SHIFT+V, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard ""
  bind = SUPER, slash,   exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
  ```

  Other handlers (Lua works the same, via `hl.dsp.exec_cmd`): mixer, calendar, media, power, battery, sysmon, recorder, gameMode, peek, hide, page …

- **Uninstall**:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
  ```

  Removes program files, all state and caches (`~/.local/state/ukishima*`, `~/.cache/ukishima`), and stops any running instance. Then drop the auto-launch line, keybinds and packages you added.

## Credits

Built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei) — the pill concept, the morphing-surface architecture and most of the original codebase. All credit for the base code goes to the original author.