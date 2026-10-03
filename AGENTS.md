# AGENTS.md

Quickshell (QML) "dynamic island" shell for Hyprland: one morphing pill per monitor (`shell.qml` + `Pill.qml`) plus a dock. Fully self-contained — it must not edit the user's Hyprland config.

## Layout / boundaries

- `shell.qml` — main entry config. `Pill.qml` is ~136 KB and holds most pill UI; edit carefully.
- `Singletons/` — shared state/services (qmldir registers `singleton X X.qml`). Add new shared state here, not in surfaces.
- `surfaces/` — per-surface QML (launcher, mixer, …). `components/` — reusable widgets. Both have qmldir import files.
- `lockscreen/` — **separate Quickshell config** (`lockscreen/shell.qml`), launched only via `scripts/lock.sh`. Never treat it as part of the main shell's import graph.
- `lib/` — plain JS helpers + `monitors.test.mjs`.
- `scripts/` — shell/python helpers; `dependencies.json` is the single source of truth consumed by `check-deps.sh`, `remote-install.sh`, and `DEPENDENCIES.md` — update it there, nowhere else.
- Runtime state: `~/.local/state/ukishima/flags.json` (e.g. `lockMethod`), cache `~/.cache/ukishima/`.

## Commands

- Run/launch: `./launch.sh` (sets jemalloc `MALLOC_CONF` decay, then execs `quickshell`/`qs -c <dir>`). Always dev through this, not bare `qs`.
- IPC (empty monitor arg = focused): `qs -p <repo> ipc call ukishima <handler> ""` — handlers: `wallpaper`, `clipboard`, `launcher`, `mixer`, `calendar`, `media`, `power`, `battery`, `sysmon`, `recorder`, `gameMode`, `peek`, `hide`, `page`, `overview`.
- Lock: `scripts/lock.sh` (hyprlock or Quickshell backend per flags.json; probes and downgrades, never leaves session unlocked).
- Tests (no framework, no package.json): `node lib/monitors.test.mjs`
- Python style config: ruff cache present; lint `scripts/wallcolors.py` with `ruff check scripts/`.

## Verification

There is no build step and no CI. Quickshell parses/validates QML at launch and exits non-zero (255 = config failed to load, e.g. unresolvable import). Minimal smoke check: launch via `./launch.sh` and confirm the pill appears / the process survives; `scripts/lock.sh`'s log at `~/.cache/ukishima/lock.log` is the pattern for diagnosing the lockscreen path.

## Gotchas

- Hyprland integration is Lua (0.55+): use `hl.dsp.*` / `hl.bind(...)` / `hl.exec_cmd(...)`; old keyword dispatcher syntax is invalid. `modules/decoration.lua` is the example.
- `Singletons`, `components`, `surfaces`, `lockscreen` are QML module dirs — new files must be added to the matching `qmldir` to be importable.
- `qs` vs `quickshell`: both names are probed everywhere; keep new scripts probing both.
- Commit style: conventional commits (`fix(overview): …`, `overview: …` in git log).
