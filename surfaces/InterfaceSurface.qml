pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 面 INTERFACE sub-surface: general shell behaviour that is not tied to the
 * clock or the theme — the UI scale, reduced motion, and whether the pill
 * auto-hides. Reached from the Appearance index and folds back to it on the
 * back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: autoHideRow, kind: "toggle", get: function () { return Flags.autoHide; }, set: function (v) { Flags.autoHide = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "面"
            title: "INTERFACE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            SettingsSeg {
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onPicked: (v) => Flags.uiScale = v
            }
        }

        SettingsRow {
            id: motionRow
            surface: root
            name: "Reduce motion"
            icon: "waves"

            LinkToggle {
                s: root.s
                on: Flags.reduceMotion
                onToggled: Flags.reduceMotion = !Flags.reduceMotion
            }
        }

        SettingsRow {
            id: autoHideRow
            surface: root
            name: "Auto hide"
            icon: "eye-off"
            last: true

            LinkToggle {
                s: root.s
                on: Flags.autoHide
                onToggled: Flags.autoHide = !Flags.autoHide
            }
        }
    }
}
