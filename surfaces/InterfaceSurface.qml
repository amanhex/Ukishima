pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 面 INTERFACE sub-surface: general shell behaviour that is not tied to the
 * clock, the theme or the dock — the UI scale, reduced motion, whether the pill
 * auto-hides, the memory saver, and the door to the right-click stops. Reached
 * from the Appearance index and folds back to it on the back chevron or an
 * empty click. Dock settings live on their own 泊 DOCK sub-surface.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: motionStyleRow, kind: "seg", vals: ["standard", "snap", "float", "bounce"], get: function () { return Flags.motionStyle; }, set: function (v) { Flags.motionStyle = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: autoHideRow, kind: "toggle", get: function () { return Flags.autoHide; }, set: function (v) { Flags.autoHide = v; } },
        { item: saverRow, kind: "toggle", get: function () { return Flags.memorySaver; }, set: function (v) { Flags.memorySaver = v; } },
        { item: clickRow, kind: "nav", surface: "rightclick" }
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

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: scaleRow
            surface: root
            name: "UI scale"
            icon: "scaling"

            Dropdown {
                id: scaleDrop
                s: root.s
                options: [{ label: "90%", value: 0.9 }, { label: "100%", value: 1.0 }, { label: "110%", value: 1.1 }, { label: "125%", value: 1.25 }]
                value: Flags.uiScale
                onChipClicked: scaleDrop.open = !scaleDrop.open
                onPicked: (v) => Flags.uiScale = v
            }
        }

        /**
         * The pill's own animation feel, separate from the dock's: how fast
         * and how shaped its morph, hover hop and hide/show run. Standard is
         * the shipped motion; Snap runs it short and punchy, Float long and
         * lazy, Bounce keeps the speed and overshoots into place.
         */
        SettingsRow {
            id: motionStyleRow
            surface: root
            name: "Motion"
            icon: "sparkles"

            Dropdown {
                id: motionStyleDrop
                s: root.s
                options: [{ label: "Standard", value: "standard" }, { label: "Snap", value: "snap" }, { label: "Float", value: "float" }, { label: "Bounce", value: "bounce" }]
                value: Flags.motionStyle
                onChipClicked: motionStyleDrop.open = !motionStyleDrop.open
                onPicked: (v) => Flags.motionStyle = v
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

            LinkToggle {
                s: root.s
                on: Flags.autoHide
                onToggled: Flags.autoHide = !Flags.autoHide
            }
        }

        SettingsRow {
            id: saverRow
            surface: root
            name: "Memory saver"
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Flags.memorySaver
                onToggled: Flags.memorySaver = !Flags.memorySaver
            }
        }

        /**
         * The right-click walk gets its own page rather than rows here: two
         * dropdowns plus their captions would double this list, and the walk is
         * its own idea (what a gesture opens) next to the pill's look-and-feel.
         */
        SettingsRow {
            id: clickRow
            surface: root
            name: "Right-click"
            sub: "Pill · media · timer · two more"
            icon: "cursor"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === clickRow ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }
    }
}
