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
    implicitHeight: content.implicitHeight

    rows: [
        { item: dispTile, kind: "nav", surface: "display" },
        { item: appearTile, kind: "nav", surface: "appcat" },
        { item: fontTile, kind: "nav", surface: "fontpicker" },
        { item: ifaceTile, kind: "nav", surface: "interface" },
        { item: lockTile, kind: "nav", surface: "locksettings" },
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
            title: "SETTINGS"
            showBack: false
        }

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: dispTile
            surface: root
            glyph: "時"
            name: "Display"
            sub: "Time · glyphs · modules"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === dispTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: appearTile
            surface: root
            glyph: "相"
            name: "Appearance"
            sub: "Theme, accent, glass, font"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearTile ? Theme.cream : Theme.iconDim
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
            id: lockTile
            surface: root
            glyph: "錠"
            name: "Lock screen"
            sub: "Method, backdrop, indicators"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === lockTile ? Theme.cream : Theme.iconDim
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
