pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 動 DOCK MOTION: animation feel — standard, snap, float, bounce.
 * Reached from DOCK SETTINGS and folds back on the back chevron.
 */
DockPanel {
    id: root

    backSurface: "dockSettings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: motionRow, kind: "seg", vals: ["standard", "snap", "float", "bounce"], get: function () { return Flags.dockMotionStyle; }, set: function (v) { Flags.dockMotionStyle = v; } }
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
            glyph: "動"
            title: "MOTION"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Motion"
            icon: "bolt"
            last: true

            Dropdown {
                id: motionDrop
                s: root.s
                pal: root.pal
                options: [{ label: "Standard", value: "standard" }, { label: "Snap", value: "snap" }, { label: "Float", value: "float" }, { label: "Bounce", value: "bounce" }]
                value: Flags.dockMotionStyle
                onChipClicked: motionDrop.open = !motionDrop.open
                onPicked: (v) => Flags.dockMotionStyle = v
            }
        }
    }
}