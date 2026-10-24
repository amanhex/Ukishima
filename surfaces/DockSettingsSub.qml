pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 泊 DOCK SETTINGS index: the top-level dock settings page. Four tiles
 * navigate to sub-pages — BEHAVIOR (auto-hide, UI scale, window gap, minimal),
 * APPEARANCE (theme, OLED, glass, manual hue), APPS (pinned app list) and
 * MOTION (animation feel). Reached from the dock's gear chip and folds back
 * to the dock bar on the back chevron or an empty click.
 */
DockPanel {
    id: root

    backSurface: ""
    implicitHeight: content.implicitHeight

    rows: [
        { item: behaviorTile, kind: "nav", surface: "dockBehavior" },
        { item: appearanceTile, kind: "nav", surface: "dockAppearance" },
        { item: appsTile, kind: "nav", surface: "dockApps" },
        { item: motionTile, kind: "nav", surface: "dockMotion" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            pal: root.pal
            glyph: "泊"
            title: "DOCK SETTINGS"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: behaviorTile
            surface: root
            glyph: "制"
            name: "Behavior"
            sub: "Auto-hide, UI scale, window gap, minimal"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === behaviorTile ? root.ink : root.dim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: appearanceTile
            surface: root
            glyph: "相"
            name: "Appearance"
            sub: "Theme, OLED, glass, manual hue"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceTile ? root.ink : root.dim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: appsTile
            surface: root
            glyph: "品"
            name: "Apps"
            sub: root.pinSummary

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appsTile ? root.ink : root.dim
                stroke: 1.9
            }
        }

        SettingsRow {
            id: motionTile
            surface: root
            glyph: "動"
            name: "Motion"
            sub: "Standard, snap, float, bounce"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === motionTile ? root.ink : root.dim
                stroke: 1.9
            }
        }
    }
}