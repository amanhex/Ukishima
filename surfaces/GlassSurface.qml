pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 玻 GLASS sub-surface: the pill's material. Transparency mode switches between
 * the translucent glass and the solid frosted look; text visibility adds extra
 * contrast for copy drawn on the glass. Reached from the Appearance index and
 * folds back to it on the back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appcat"
    implicitHeight: content.implicitHeight

    rows: [
        { item: glassRow, kind: "toggle", get: function () { return Flags.glass; }, set: function (v) { Flags.glass = v; } },
        { item: glassTextRow, kind: "seg", vals: [0, 0.5, 1], get: function () { return Flags.glassText; }, set: function (v) { Flags.glassText = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "玻"
            title: "GLASS"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: glassRow
            surface: root
            name: "Transparency mode"
            icon: "droplet"
            sub: "Translucent pill · desktop shows through"

            LinkToggle {
                s: root.s
                on: Flags.glass
                onToggled: Flags.glass = !Flags.glass
            }
        }

        SettingsRow {
            id: glassTextRow
            surface: root
            name: "Contrast"
            icon: "type"
            sub: "Extra contrast for copy on the glass"
            enabled: Flags.glass
            last: true

            Dropdown {
                id: glassTextDrop
                s: root.s
                up: true
                options: [
                    { label: "Off", value: 0 },
                    { label: "Soft", value: 0.5 },
                    { label: "Strong", value: 1 }
                ]
                value: Flags.glassText || 0
                onChipClicked: glassTextDrop.open = !glassTextDrop.open
                onPicked: (v) => Flags.glassText = v
            }
        }
    }
}