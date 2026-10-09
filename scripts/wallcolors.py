#!/usr/bin/env python3
"""
Generate the rice colour set from a wallpaper and fan it out to the consumers.
One histogram pass yields both the area-dominant chromatic hue (binned by hue
family so a small vivid accent never hijacks the theme) and the mean lightness.
The mean lightness drives the pill's whole tone: a bright wallpaper makes a light
pill with dark text, a dark or OLED-black one makes a near-black pill with cream
text, so the surfaces and the text flip together for contrast across the full
range. The dominant hue tints every tier in HSL. An achromatic wallpaper drops to
a neutral grey ramp.

The terminal gets a normal light scheme no matter the pill's tone: a near-white,
hue-tinted background with dark text tiers (the classic default look), then the
16 ANSI slots are shaped by matugen's light variant so the readout stays legible
on the light background. The pill JSON carries surfaces, accent and the
contrast-matched text.

--hue is the rice-only mode: it renders fastfetch, GTK, Hyprland and the terminal
from the chosen hue but no longer writes the shared colors.json. The pill's
manual palette and the dock's manual palette are computed locally from their own
hue flags (Singletons/PaletteHue.qml) instead, so a manual slider recolours only
the side that owns it — colors.json stays the wallpaper palette that dynamic
modes on both sides read.
"""
import colorsys
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# All cache lands in the single ukishima folder under the cache dir, resolved the
# same way the QML side and the thumb scripts do (Dyn reads this file).
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "ukishima"

SURF_NAMES = ["surface", "surface_container_low", "surface_container",
              "surface_container_high", "surface_container_highest", "outline_variant"]
DARK_STEPS = [0.0, 0.022, 0.038, 0.065, 0.100, 0.225]
LIGHT_STEPS = [0.0, -0.045, -0.075, -0.115, -0.160, -0.340]
TEXT_KEYS = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"]
DARK_TEXT = [(0.90, 0.05), (0.97, 0.03), (0.73, 0.07), (0.54, 0.06),
             (0.44, 0.05), (0.81, 0.07), (0.75, 0.08)]
LIGHT_TEXT = [(0.20, 0.18), (0.10, 0.20), (0.36, 0.14), (0.48, 0.10),
              (0.56, 0.08), (0.28, 0.12), (0.34, 0.12)]


def analyze(wallpaper):
    # Bounded: a wedged magick would hang the caller (the QML Process and
    # wallpaper.sh both wait on this), and an unbounded child is exactly what
    # leaves a shell sitting in the process list. Degrades to a neutral palette.
    try:
        out = subprocess.run(
            ["magick", wallpaper, "-alpha", "off", "-resize", "200x200", "-colors", "48",
             "-format", "%c", "histogram:info:-"],
            capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None, 0.0, 0.5
    buckets, total, lum, chroma = {}, 0, 0.0, 0
    for line in out.splitlines():
        m = re.search(r"\s*(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6})", line)
        if not m:
            continue
        count, hex_str = int(m.group(1)), m.group(2)
        r, g, b = (int(hex_str[i:i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        total += count
        lum += count * l
        if s < 0.15 or l < 0.05 or l > 0.92:
            continue
        chroma += count
        bucket = buckets.setdefault((int(h * 360) // 30) % 12, {"wsat": 0.0, "best": None})
        bucket["wsat"] += count * s
        score = count * s * (1 if 0.12 < l < 0.55 else 0.4)
        if not bucket["best"] or score > bucket["best"][0]:
            bucket["best"] = (score, h, s)
    mean_l = lum / total if total else 0.0
    if not buckets or chroma < 0.08 * total:
        return None, 0.0, mean_l
    win = max(buckets.values(), key=lambda v: v["wsat"])
    return win["best"][1], win["best"][2], mean_l


def matugen(source_hex):
    # Bounded like magick above; the caller already treats a SubprocessError
    # (TimeoutExpired included) as "no matugen" and falls back to its own ramp.
    out = subprocess.run(
        ["matugen", "color", "hex", source_hex, "-m", "dark", "-j", "hex"],
        capture_output=True, text=True, check=True, timeout=15,
    )
    return json.loads(out.stdout)


def tint(hue, sat, light):
    r, g, b = colorsys.hls_to_rgb(hue % 1.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def lerp(x, x0, x1, y0, y1):
    t = max(0.0, min(1.0, (x - x0) / (x1 - x0)))
    return y0 + t * (y1 - y0)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def to_hex(v):
    return "#%02x%02x%02x" % tuple(round(c * 255) for c in v)


def lum(h):
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb(h)]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def contrast(a, b):
    l1, l2 = lum(a), lum(b)
    lo, hi = min(l1, l2), max(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def ensure_contrast(color, bg, ratio):
    """Shift a colour until it clears ratio:1 against bg, keeping its hue:
    toward white on a dark background, toward black on a light one."""
    if contrast(color, bg) >= ratio:
        return color
    h, l, s = colorsys.rgb_to_hls(*rgb(color))
    dark_bg = lum(bg) < 0.5
    lo, hi = (l, 1.0) if dark_bg else (0.0, l)
    for _ in range(30):
        mid = (lo + hi) / 2
        if contrast(to_hex(colorsys.hls_to_rgb(h, mid, s)), bg) >= ratio:
            if dark_bg:
                hi = mid
            else:
                lo = mid
        else:
            if dark_bg:
                lo = mid
            else:
                hi = mid
    return to_hex(colorsys.hls_to_rgb(h, hi if dark_bg else lo, s))


def make_pill(hue, sat, chromatic, mean_l, dark):
    light = not dark
    surf_sat = min(sat, 0.26) if light else min(max(sat, 0.30 if chromatic else 0.0), 0.45)
    acc_sat = (min(sat + 0.18, 0.85) if light else min(max(sat, 0.30) + 0.12, 0.82)) if chromatic else 0.05
    if light:
        base = lerp(mean_l, 0.40, 0.66, 0.80, 0.93)
        steps, text, acc_l, deep_l, glow_l = LIGHT_STEPS, LIGHT_TEXT, 0.42, 0.30, 0.55
    else:
        base = lerp(mean_l, 0.0, 0.40, 0.045, 0.20)
        steps, text, acc_l, deep_l, glow_l = DARK_STEPS, DARK_TEXT, 0.70, 0.34, 0.86

    pill = {name: tint(hue, surf_sat, base + step) for name, step in zip(SURF_NAMES, steps)}
    pill["primary"] = tint(hue, acc_sat, acc_l)
    pill["primary_container"] = tint(hue, min(acc_sat + 0.08, 0.9), deep_l)
    pill["on_primary_container"] = tint(hue, min(acc_sat, 0.45), glow_l)
    pill["outline"] = tint(hue, surf_sat, base + (-0.35 if light else 0.35))
    for key, (lit, st) in zip(TEXT_KEYS, text):
        pill[key] = tint(hue, st, lit)
    return pill


def render_fastfetch(pill):
    """
    Recolour the fastfetch readout from the same pill palette. fastfetch has no
    daemon, so writing the rendered config is enough, the next run picks it up.
    The accent drives the keys and the torii, the surface ramp the lantern body,
    and a dim text tone the section rules, so it tracks the wallpaper like the
    pill and terminal do.
    """
    ff = Path.home() / ".config" / "fastfetch"
    tmpl = ff / "config.jsonc.in"
    if not tmpl.is_file():
        return
    seq = lambda h: "%d;%d;%d" % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    repl = {
        "__LANTERN__": str(ff / "lantern.txt"),
        "__KEYS__": seq(pill["primary"]),
        "__SEP__": seq(pill["dim"]),
        "__LOGO1__": seq(pill["primary"]),
        "__LOGO2__": seq(pill["on_primary_container"]),
        "__LOGO3__": seq(pill["surface_container"]),
        "__LOGO4__": seq(pill["surface_container_high"]),
        "__LOGO5__": seq(pill["subtle"]),
        "__LOGO6__": seq(pill["outline"]),
        "__LOGO7__": seq(pill["bright"]),
    }
    out = tmpl.read_text()
    for key, val in repl.items():
        out = out.replace(key, val)
    (ff / "config.jsonc").write_text(out)


def ensure_gtk_import(d, pairs):
    """
    Make each named css in `d` load its palette file last so the wallpaper
    palette wins. A symlinked css (theme switchers link the system theme
    read-only) becomes a real file importing the resolved theme first, so
    the theme keeps applying underneath; a real file gets one appended
    @import; a missing file is created with just the import. Idempotent.
    """
    for name, imp in pairs.items():
        line = '@import "%s";' % imp
        try:
            main = d / name
            if main.is_symlink():
                target = Path(os.readlink(main))
                if not target.is_absolute():
                    target = d / target
                main.unlink()
                main.write_text('@import url("file://%s");\n%s\n' % (target.resolve(), line))
            elif main.is_file():
                cur = main.read_text()
                if imp not in cur:
                    if not cur.endswith("\n"):
                        cur += "\n"
                    main.write_text(cur + line + "\n")
            else:
                main.write_text(line + "\n")
        except OSError:
            pass


def gtk_body(pill):
    accent = pill["primary"]
    mapping = [
        ("accent_color", accent),
        ("accent_bg_color", accent),
        ("accent_fg_color", ensure_contrast(pill["bright"], accent, 4.5)),
        ("window_bg_color", pill["surface"]),
        ("window_fg_color", pill["cream"]),
        ("headerbar_bg_color", pill["surface_container"]),
        ("headerbar_fg_color", pill["cream"]),
        ("popover_bg_color", pill["surface_container_high"]),
        ("popover_fg_color", pill["cream"]),
        ("view_bg_color", pill["surface_container_low"]),
        ("view_fg_color", pill["cream"]),
        ("card_bg_color", pill["surface_container"]),
        ("card_fg_color", pill["cream"]),
        ("sidebar_bg_color", pill["surface_container_low"]),
        ("sidebar_fg_color", pill["cream"]),
        ("destructive_color", "#e05a4f"),
        ("destructive_bg_color", "#5a2320"),
        ("destructive_fg_color", "#f5d9d4"),
        ("success_color", "#8fb573"),
        ("warning_color", "#d9a03f"),
        ("borders", pill["outline"]),
    ]
    return ("/* Generated by ukishima wallcolors.py - do not hand-edit. */\n"
            + "\n".join("@define-color %s %s;" % kv for kv in mapping) + "\n")


def render_gtk(tone, dark):
    """
    Recolour GTK3/GTK4 libadwaita apps from the pill palette. gtk-3.0 and
    the gtk-4.0 dark file take the dark ramp (the desktop is dark);
    gtk-4.0/gtk.css follows the pill tone. The user's theme files keep
    applying underneath - delete the import line to opt out. GTK reads its
    css at app start, so running apps pick a new wallpaper up on relaunch.
    """
    try:
        d3 = Path.home() / ".config" / "gtk-3.0"
        d3.mkdir(parents=True, exist_ok=True)
        (d3 / "ukishima.css").write_text(gtk_body(dark))
        ensure_gtk_import(d3, {"gtk.css": "ukishima.css"})
        d4 = Path.home() / ".config" / "gtk-4.0"
        d4.mkdir(parents=True, exist_ok=True)
        (d4 / "ukishima.css").write_text(gtk_body(tone))
        (d4 / "ukishima-dark.css").write_text(gtk_body(dark))
        ensure_gtk_import(d4, {"gtk.css": "ukishima.css",
                               "gtk-dark.css": "ukishima-dark.css"})
    except OSError:
        pass


def main():
    if len(sys.argv) < 2:
        return 1
    hue_only = sys.argv[1] == "--hue"
    if hue_only:
        hue = (float(sys.argv[2]) % 360) / 360.0
        mode = sys.argv[3] if len(sys.argv) > 3 else "dark"
        sat = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
        sat = max(0.0, min(1.0, sat))
        mean_l = 0.85 if mode == "light" else 0.12
        chromatic = sat > 0.02
    else:
        wallpaper = sys.argv[1]
        if not Path(wallpaper).is_file():
            return 0
        hue, sat, mean_l = analyze(wallpaper)
        chromatic = hue is not None
        if not chromatic:
            hue, sat = 0.09, 0.0
    CACHE.mkdir(parents=True, exist_ok=True)

    light = mean_l >= 0.40
    pill = make_pill(hue, sat, chromatic, mean_l, not light)
    dark_pill = pill if not light else make_pill(hue, sat, chromatic, 0.12, True)
    if not hue_only:
        # colors.json is the shared WALLPAPER palette (read by Dyn for the pill's
        # and the dock's dynamic modes). --hue keeps it untouched so a manual
        # slider never restyles the other side's dynamic palette.
        (CACHE / "colors.json").write_text(json.dumps(pill, indent=2) + "\n")
        # colors-dark.json is the same hue on the dark ramp, for dark-only
        # consumers (GTK dark file, the screenshot studio). Same --hue rule.
        (CACHE / "colors-dark.json").write_text(json.dumps(dark_pill, indent=2) + "\n")
    render_fastfetch(pill)
    render_gtk(pill, dark_pill)

    try:
        # Terminal ramp: a normal light scheme (dark text tiers on the
        # terminal's OWN background — the background is never overridden, so a
        # transparent/blurred terminal keeps its configured look). base07
        # clears ~7:1 and base04 ~4.5:1 against a light background.
        ramp = [(0.93, 0.03), (0.88, 0.03), (0.80, 0.03), (0.70, 0.04),
                (0.55, 0.05), (0.40, 0.05), (0.25, 0.04), (0.13, 0.03)]
        b = {"base%02x" % i: tint(hue, s, l) for i, (l, s) in enumerate(ramp)}
        b00 = b["base00"]
        # matugen shapes the 16 ANSI slots from its light variant; a hue-anchored
        # ramp covers its absence.
        try:
            theme = matugen(tint(hue, sat, 0.45) if chromatic else "#787878")
            ansi = [theme["base16"]["base%02x" % i]["light"]["color"]
                    for i in range(8, 16)]
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            ansi = [tint(h, s, l) for (h, s, l) in (
                (0.00, 0.55, 0.45), (0.062, 0.55, 0.40), (0.14, 0.50, 0.42),
                (0.33, 0.47, 0.40), (0.50, 0.45, 0.40), (0.60, 0.50, 0.42),
                (0.76, 0.50, 0.42), (0.083, 0.60, 0.38))]
        for i, c in enumerate(ansi):
            b["base%02x" % (8 + i)] = ensure_contrast(c, b00, 3.0)

        (CACHE / "hypr-colors.lua").write_text(
            'return {\n    active = "%s",\n    inactive = "%s",\n}\n'
            % (pill["primary"], b["base01"]))

        lines = [
            f'foreground = {b["base07"]}',
            f'cursor-color = {pill["primary"]}',
            f'selection-background = {b["base02"]}',
            f'selection-foreground = {b["base07"]}',
        ]
        for i in range(16):
            lines.append(f'palette = {i}={b["base%02x" % i]}')
        (CACHE / "ghostty-colors").write_text("\n".join(lines) + "\n")

        kitty_lines = [
            f'foreground {b["base07"]}',
            f'cursor {pill["primary"]}',
            f'selection_background {b["base02"]}',
            f'selection_foreground {b["base07"]}',
        ]
        for i in range(16):
            kitty_lines.append(f'color{i} {b["base%02x" % i]}')
        (CACHE / "kitty-colors").write_text("\n".join(kitty_lines) + "\n")
    except (OSError, subprocess.SubprocessError):
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
