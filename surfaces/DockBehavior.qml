pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 制 DOCK BEHAVIOR: auto-hide, UI scale, window gap, minimal mode.
 * Reached from DOCK SETTINGS and folds back on the back chevron.
 */
DockPanel {
    id: root

    backSurface: "dockSettings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: autoHideRow, kind: "toggle", get: function () { return Flags.dockAutoHide; }, set: function (v) { Flags.dockAutoHide = v; } },
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: gapRow, kind: "seg", vals: [0.25, 0.5, 1.0, 1.5], get: function () { return Flags.dockGap; }, set: function (v) { Flags.dockGap = v; } },
        { item: minimalRow, kind: "toggle", get: function () { return Flags.dockMinimal; }, set: function (v) { Flags.dockMinimal = v; } }
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
            glyph: "制"
            title: "BEHAVIOR"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: autoHideRow
            surface: root
            name: "Auto-hide"
            icon: "eye-off"

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockAutoHide
                onToggled: Flags.dockAutoHide = !Flags.dockAutoHide
            }
        }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            Dropdown {
                id: scaleDrop
                s: root.s
                pal: root.pal
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onChipClicked: scaleDrop.open = !scaleDrop.open
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: gapRow
            surface: root
            name: "Window gap"
            icon: "monitor"
            visible: !Flags.dockAutoHide

            Dropdown {
                id: gapDrop
                s: root.s
                pal: root.pal
                options: [{ label: "25%", value: 0.25 }, { label: "50%", value: 0.5 }, { label: "100%", value: 1 }, { label: "150%", value: 1.5 }]
                value: Flags.dockGap
                onChipClicked: gapDrop.open = !gapDrop.open
                onPicked: (v) => Flags.dockGap = v
            }
        }

        SettingsRow {
            id: minimalRow
            surface: root
            name: "Minimal dock"
            icon: "dot"
            last: true

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockMinimal
                onToggled: Flags.dockMinimal = !Flags.dockMinimal
            }
        }
    }
}