pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 相 APPEARANCE index: the door into the appearance settings, split into four
 * category tiles — DISPLAY (pill layout, clock, glyphs), THEME (colours and the
 * wallpaper folder), FONT (the family picker) and INTERFACE (scale, motion,
 * auto-hide). Picking a tile morphs the pill into that category's sub-surface;
 * the back chevron on each returns here, and an empty click or the cog closes.
 * Reached from the pill's hover row and folds back into it on a dismiss.
 */
SettingsSurface {
    id: root

    backSurface: ""
    implicitHeight: content.implicitHeight

    rows: [
        { item: dispTile, kind: "nav", surface: "display" },
        { item: themeTile, kind: "nav", surface: "theme" },
        { item: fontTile, kind: "nav", surface: "fontpicker" },
        { item: ifaceTile, kind: "nav", surface: "interface" },
        { item: updateTile, kind: "nav", surface: "update" }
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
            showBack: false
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: dispTile
            surface: root
            glyph: "時"
            name: "Display"
            sub: "Pill layout · time · glyphs"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === dispTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

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
            id: fontTile
            surface: root
            glyph: "字"
            name: "Font"
            sub: "UI family and fallback"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === fontTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: ifaceTile
            surface: root
            glyph: "面"
            name: "Interface"
            sub: "Scale, motion, auto-hide"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === ifaceTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: updateTile
            surface: root
            glyph: "更"
            name: "Update"
            sub: "Pull latest from GitHub"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === updateTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
