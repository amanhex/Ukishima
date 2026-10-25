# 浮島 Ukishima

> A dynamic-island Quickshell shell for Hyprland and niri.

Ukishima (浮島, *"floating island"*) is a widget layer for Hyprland and niri built around a morphing pill at the top of every monitor that expands in place into a control centre, plus a floating macOS-style 泊 dock at the bottom edge for pinned and running apps. Fully self-contained — it makes no changes to your compositor config.

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
- **Surfaces** — launcher, weather, calendar, media, mixer, wallpaper strip + wallhaven search, screen recorder, clipboard, wifi, bluetooth, battery, power menu, system monitor, notifications, OSD, toasts, scratchpad, settings.
- **Wallpapers** — shuffled `awww` bag, live `mpvpaper` videos, per-wallpaper fit, and a palette that retints the UI.
- **Compositor-aware** — a small `Wm` seam uses Hyprland's IPC where it exists and generic Wayland protocols on niri; Hyprland-only rows hide themselves instead of failing.
- **Extras** — night light (Hyprland today; niri planned), game mode, keep-awake, in-app updater.

## Compositor support

Ukishima works on both Hyprland and niri. The pill, dock, surfaces, wallpapers,
notifications, lock, and game mode are shared between them. Hyprland‑only rows
(special workspaces, minimized tray, workspace rules, keyboard layout, global
media keys) hide themselves when running on niri. Night light uses
`hyprsunset` on Hyprland and is planned for niri.

Keybinds are compositor‑specific: Hyprland uses `SUPER` (or your modifier) while
niri defaults to `Super`. The `spawn-sh` helper runs the command through a
shell, so `$HOME` expands correctly.

## Requirements

- Linux + Wayland, **Hyprland** (recent 0.4x/0.5x) **or niri**
- **Quickshell** 0.3.0+ (Wayland and Io modules; the Hyprland module is used only on Hyprland)
- CLI tools — the installer checks them; see [DEPENDENCIES](DEPENDENCIES.md)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/remote-install.sh | bash
```

Clones to `~/.local/share/quickshell/ukishima`, checks dependencies, and prints the auto-launch line plus the IPC surface list you can bind to your own keys. Update it the same way — or from the **Update** surface inside the settings — whenever you want the latest.

The installer never edits your compositor config. Add the launch line and the keybinds you want yourself; the examples below cover both compositors.

## Use

### Auto-launch and keybinds

Launch through **`launch.sh`** — it adds jemalloc decay settings so memory stays near the live working set instead of the session peak (~250 MB RSS). Start `awww-daemon` beside it so the wallpaper is painted without waiting on the daemon to come up.

Ukishima ships no keybinds of its own. Every surface answers over IPC, so bind the ones you want; the examples are a starting point, not a required set.

<details>
<summary><b>Hyprland — hyprlang</b></summary>

```ini
# ~/.config/hypr/hyprland.conf
exec-once = ~/.local/share/quickshell/ukishima/launch.sh
exec-once = awww-daemon

bind = SUPER SHIFT, W, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima wallpaper ""
bind = SUPER SHIFT, V, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima clipboard ""
bind = SUPER, slash, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
bind = SUPER, N, exec, qs -p ~/.local/share/quickshell/ukishima ipc call ukishima notifications ""
bind = SUPER, L, exec, ~/.local/share/quickshell/ukishima/scripts/lock.sh
```

</details>

<details>
<summary><b>Hyprland — Lua</b></summary>

`var_mainMod` is whatever your Lua config calls the main modifier; substitute your own name if yours differs.

```lua
hl.exec_cmd("~/.local/share/quickshell/ukishima/launch.sh")
hl.exec_cmd("awww-daemon")

local uk = "qs -p ~/.local/share/quickshell/ukishima"
hl.bind(var_mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(uk .. " ipc call ukishima wallpaper \"\""))
hl.bind(var_mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(uk .. " ipc call ukishima clipboard \"\""))
hl.bind(var_mainMod .. " + slash", hl.dsp.exec_cmd(uk .. " ipc call ukishima launcher \"\""))
hl.bind(var_mainMod .. " + N", hl.dsp.exec_cmd(uk .. " ipc call ukishima notifications \"\""))
hl.bind(var_mainMod .. " + L", hl.dsp.exec_cmd("~/.local/share/quickshell/ukishima/scripts/lock.sh"))
```

</details>

<details>
<summary><b>niri — KDL</b></summary>

niri's `Mod` is Super by default. `spawn-sh` runs the command through a shell, so `$HOME` expands.

```kdl
// ~/.config/niri/config.kdl
spawn-at-startup "sh" "-c" "exec $HOME/.local/share/quickshell/ukishima/launch.sh"
spawn-at-startup "awww-daemon"

binds {
    Mod+Shift+W { spawn-sh "qs -p $HOME/.local/share/quickshell/ukishima ipc call ukishima wallpaper \"\""; }
    Mod+Shift+V { spawn-sh "qs -p $HOME/.local/share/quickshell/ukishima ipc call ukishima clipboard \"\""; }
    Mod+Slash { spawn-sh "qs -p $HOME/.local/share/quickshell/ukishima ipc call ukishima launcher \"\""; }
    Mod+N { spawn-sh "qs -p $HOME/.local/share/quickshell/ukishima ipc call ukishima notifications \"\""; }
    Mod+L { spawn-sh "$HOME/.local/share/quickshell/ukishima/scripts/lock.sh"; }
}
```

</details>

### IPC calls

Most calls take a monitor name; pass `""` to target the focused monitor. Calling the same surface again toggles it closed.

<details>
<summary><b>IPC reference</b></summary>

```bash
# List every call the running shell exposes
qs -p ~/.local/share/quickshell/ukishima ipc show

# Example: open the launcher on the focused monitor
qs -p ~/.local/share/quickshell/ukishima ipc call ukishima launcher ""
```

Surface names and a one-line description:

- `launcher` – app launcher
- `wallpaper` – wallpaper strip and wallhaven search
- `clipboard` – clipboard history
- `notifications` – notification history
- `battery` – battery surface
- `sysmon` / `system` – system monitor
- `recorder` / `record` / `screenrec` – screen recorder
- `quickRecord` – start, stop, cancel or dismiss the quick-record flow
- `gameMode` – toggle game mode
- `power` – power menu
- `peek` – toggle the pill's peek view
- `hide` – close the open surface
- `page` – open any surface by name
- `unloadAll` – free every closed surface immediately
- `minimizeWindow` / `restoreWindow` – minimize/restore (Hyprland)
- `emoji` – emoji picker
- `calendar` – calendar
- `mixer` – audio mixer
- `media` – media surface (if a player is running)
- `appearance`, `appcat`, `display`, `modules`, `theme`, `accent`, `glass`,
  `fontcolor`, `interface`, `rightclick`, `fontpicker`, `profile`, `update`,
  `locksettings` – settings pages
- `wifi`, `bt`, `weather`, `timer` – regular surfaces
</details>

### Lock

Lock is a script, not an IPC surface:

```bash
~/.local/share/quickshell/ukishima/scripts/lock.sh
```

The lock can hand off to a standalone locker or use the built-in Quickshell lockscreen. Set the backend under **Lock** in settings (the built-in lock's background, blur, avatar and indicators live there too).

### Wallpaper daemon

`awww-daemon` is started by the launch examples above. If you prefer to let the shell start it on demand, omit that line; the first wallpaper paint just waits for the daemon to come up.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/amanhex/Ukishima/master/uninstall.sh | bash
```

Removes program files, all state and caches (`~/.local/state/ukishima*`, `~/.cache/ukishima`), and stops any running instance. Then drop the launch line, keybinds and packages you added.

## Credits

Built on top of [**Ricelin**](https://github.com/Gakuseei/Ricelin) by [**Gakuseei**](https://github.com/Gakuseei) — the pill concept, the morphing-surface architecture and most of the original codebase. All credit for the base code goes to the original author.
