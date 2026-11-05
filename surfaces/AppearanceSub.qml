pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 相 APPEARANCE sub-index: the appearance category inside Settings. Four tiles
 * carry the pill's look — THEME (light, dark, dynamic or manual), ACCENT (the
 * warm-colour override), GLASS (pill material and copy contrast) and FONT COLOUR
 * (the text-family override) — plus a SURFACE STYLES tile that opens the
 * per-surface variant pickers. Reached from the Settings index and folds back to
 * it on the back chevron or an empty click; picking a tile morphs into that
 * surface.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"

    rows: [
        { item: themeTile, kind: "nav", surface: "theme" },
        { item: accentTile, kind: "nav", surface: "accent" },
        { item: glassTile, kind: "nav", surface: "glass" },
        { item: fontColorTile, kind: "nav", surface: "fontcolor" },
        { item: stylesTile, kind: "nav", surface: "surfacestyles" }
    ]

    glyph: "相"
    title: "APPEARANCE"
    showBack: true

    SettingsRow {
        id: themeTile
        surface: root
        glyph: "色"
        name: "Theme"
        sub: "Light, dark, dynamic or manual"

        chevron: true
    }

    SettingsRow {
        id: accentTile
        surface: root
        glyph: "彩"
        name: "Accent"
        sub: "Override the warm accent colour"

        chevron: true
    }

    SettingsRow {
        id: glassTile
        surface: root
        glyph: "玻"
        name: "Glass"
        sub: "Pill material and copy contrast"

        chevron: true
    }

    SettingsRow {
        id: fontColorTile
        surface: root
        glyph: "字"
        name: "Font colour"
        sub: "Recolour the text family"

        chevron: true
    }

    SettingsRow {
        id: stylesTile
        surface: root
        glyph: "枠"
        name: "Surface Styles"
        sub: "Pill face, players, lock layout"
        last: true

        chevron: true
    }

}
