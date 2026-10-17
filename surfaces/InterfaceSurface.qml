pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 面 INTERFACE sub-surface: general shell behaviour that is not tied to the
 * clock, the theme or the dock — the UI scale, reduced motion, whether the pill
 * auto-hides, the memory saver, and what the bar's right-click walks through.
 * Reached from the Appearance index and folds back to it on the back chevron or
 * an empty click. Dock settings live on their own 泊 DOCK sub-surface.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    /**
     * The surfaces stops 3-5 can name, as one list so the dropdown menus and the
     * keyboard's seg cycling can never disagree. The media surface is absent
     * because it is stop 2 and fixed; Off skips a stop, and three Offs leave
     * right-click as the rest <-> media toggle it has always been.
     */
    readonly property var cycleChoices: [
        { label: "Off", value: "" },
        { label: "Calendar", value: "calendar" },
        { label: "Weather", value: "weather" },
        { label: "Launcher", value: "launcher" },
        { label: "Clipboard", value: "clipboard" },
        { label: "Scratchpad", value: "scratch" },
        { label: "Wallpaper", value: "wallpaper" },
        { label: "Power", value: "power" },
        { label: "Mixer", value: "mixer" },
        { label: "Link", value: "link" },
        { label: "Wi-Fi", value: "wifi" },
        { label: "Bluetooth", value: "bt" },
        { label: "Battery", value: "battery" },
        { label: "Recorder", value: "recorder" },
        { label: "System monitor", value: "sysmon" },
        { label: "Appearance", value: "appearance" },
        { label: "Profile", value: "profile" }
    ]

    readonly property var cycleVals: {
        const out = [];
        for (let i = 0; i < root.cycleChoices.length; i++)
            out.push(root.cycleChoices[i].value);
        return out;
    }

    rows: [
        { item: scaleRow, kind: "seg", vals: [0.9, 1.0, 1.1, 1.25], get: function () { return Flags.uiScale; }, set: function (v) { Flags.uiScale = v; } },
        { item: motionStyleRow, kind: "seg", vals: ["standard", "snap", "float", "bounce"], get: function () { return Flags.motionStyle; }, set: function (v) { Flags.motionStyle = v; } },
        { item: motionRow, kind: "toggle", get: function () { return Flags.reduceMotion; }, set: function (v) { Flags.reduceMotion = v; } },
        { item: autoHideRow, kind: "toggle", get: function () { return Flags.autoHide; }, set: function (v) { Flags.autoHide = v; } },
        { item: saverRow, kind: "toggle", get: function () { return Flags.memorySaver; }, set: function (v) { Flags.memorySaver = v; } },
        { item: cycleRow1, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot1; }, set: function (v) { Flags.cycleSlot1 = v; } },
        { item: cycleRow2, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot2; }, set: function (v) { Flags.cycleSlot2 = v; } },
        { item: cycleRow3, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot3; }, set: function (v) { Flags.cycleSlot3 = v; } }
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

        Item { width: 1; height: 10 * root.s }

        /**
         * Stops 3-5 of the right-click walk, one row each. Stop 1 is the
         * collapsed pill and stop 2 the media surface, so these are the three
         * the user owns: right-click opens each in turn and wraps back to the
         * clock. Off drops a stop from the walk entirely.
         */
        SettingsRow {
            id: cycleRow1
            surface: root
            name: "Right-click 3rd"
            sub: "rest · media · 3rd · 4th · 5th"
            icon: "cursor"

            Dropdown {
                id: cycleDrop1
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot1
                onChipClicked: cycleDrop1.open = !cycleDrop1.open
                onPicked: (v) => Flags.cycleSlot1 = v
            }
        }

        SettingsRow {
            id: cycleRow2
            surface: root
            name: "Right-click 4th"
            icon: "cursor"

            Dropdown {
                id: cycleDrop2
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot2
                onChipClicked: cycleDrop2.open = !cycleDrop2.open
                onPicked: (v) => Flags.cycleSlot2 = v
            }
        }

        SettingsRow {
            id: cycleRow3
            surface: root
            name: "Right-click 5th"
            icon: "cursor"
            last: true

            Dropdown {
                id: cycleDrop3
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot3
                onChipClicked: cycleDrop3.open = !cycleDrop3.open
                onPicked: (v) => Flags.cycleSlot3 = v
            }
        }
    }
}
