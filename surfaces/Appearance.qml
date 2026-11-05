pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 相 SETTINGS index: the door into the settings, split into six category tiles —
 * DISPLAY (clock, glyphs), APPEARANCE (theme, accent, glass, font colour and the
 * per-surface variants — opens its own sub-index), FONT (the family picker),
 * INTERFACE (scale, motion, auto-hide), LOCK (the session lock) and UPDATE (pull
 * latest). Picking a tile morphs the pill into that category's surface; the back
 * chevron on each returns here, and an empty click or the cog closes. Reached
 * from the pill's hover row and folds back into it on a dismiss.
 */
SettingsSurface {
    id: root

    backSurface: ""

    rows: [
        { item: dispTile, kind: "nav", surface: "display" },
        { item: appearTile, kind: "nav", surface: "appcat" },
        { item: fontTile, kind: "nav", surface: "fontpicker" },
        { item: ifaceTile, kind: "nav", surface: "interface" },
        { item: lockTile, kind: "nav", surface: "locksettings" },
        { item: updateTile, kind: "nav", surface: "update" }
    ]

    glyph: "相"
    title: "SETTINGS"
    showBack: false

    SettingsRow {
        id: dispTile
        surface: root
        glyph: "時"
        name: "Display"
        sub: "Time · glyphs · modules"

        chevron: true
    }

    SettingsRow {
        id: appearTile
        surface: root
        glyph: "相"
        name: "Appearance"
        sub: "Theme, accent, glass, font"

        chevron: true
    }

    SettingsRow {
        id: fontTile
        surface: root
        glyph: "字"
        name: "Font"
        sub: "UI family and fallback"

        chevron: true
    }

    SettingsRow {
        id: ifaceTile
        surface: root
        glyph: "面"
        name: "Interface"
        sub: "Scale, motion, auto-hide"

        chevron: true
    }

    SettingsRow {
        id: lockTile
        surface: root
        glyph: "錠"
        name: "Lock screen"
        sub: "Method, backdrop, indicators"

        chevron: true
    }

    SettingsRow {
        id: updateTile
        surface: root
        glyph: "更"
        name: "Update"
        sub: "Pull latest from GitHub"
        last: true

        chevron: true
    }

}
