pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 相 APPEARANCE sub-index: the appearance category inside Settings. Four tiles
 * carry the pill's look — THEME (light, dark, dynamic or manual), ACCENT (the
 * warm-colour override), GLASS (pill material and copy contrast) and FONT COLOUR
 * (the text-family override). Reached from the Settings index and folds back to
 * it on the back chevron or an empty click; picking a tile morphs into that
 * surface.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: themeTile, kind: "nav", surface: "theme" },
        { item: accentTile, kind: "nav", surface: "accent" },
        { item: glassTile, kind: "nav", surface: "glass" },
        { item: fontColorTile, kind: "nav", surface: "fontcolor" },
        { item: stylesTile, kind: "nav", surface: "surfacestyles" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "相"
            title: "APPEARANCE"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: themeTile
            surface: root
            glyph: "色"
            name: "Theme"
            sub: "Light, dark, dynamic or manual"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === themeTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: accentTile
            surface: root
            glyph: "彩"
            name: "Accent"
            sub: "Override the warm accent colour"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === accentTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: glassTile
            surface: root
            glyph: "玻"
            name: "Glass"
            sub: "Pill material and copy contrast"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === glassTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: fontColorTile
            surface: root
            glyph: "字"
            name: "Font colour"
            sub: "Recolour the text family"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === fontColorTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: stylesTile
            surface: root
            glyph: "枠"
            name: "Surface Styles"
            sub: "Choose UI styles for surfaces"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === stylesTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
