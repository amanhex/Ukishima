pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 右 RIGHT-CLICK sub-surface: the two stops the bar's right-click walk leaves to
 * the user. Stops 1-3 are fixed — the collapsed pill, the media surface and the
 * timer — so these two rows pick shell stops 4 and 5, and Off drops one from the
 * walk. Reached from INTERFACE and folds back to it on the back chevron or an
 * empty click.
 */
SettingsSurface {
    id: root

    backSurface: "interface"
    implicitHeight: content.implicitHeight

    /**
     * The surfaces these stops can name, as one list so the dropdown menus and
     * the keyboard's seg cycling can never disagree. The colour-theme pages and
     * the lock page are absent: they are doors into settings rather than things
     * to pop up, and media and timer are already fixed as stops 2 and 3.
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
        { item: slot4Row, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot4; }, set: function (v) { Flags.cycleSlot4 = v; } },
        { item: slot5Row, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot5; }, set: function (v) { Flags.cycleSlot5 = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "右"
            title: "RIGHT-CLICK"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        /**
         * The two user-owned stops. The walk is the collapsed pill, the media
         * surface and the timer, then these in turn, wrapping back to the
         * clock — Off leaves the step out instead of stalling it.
         */
        SettingsRow {
            id: slot4Row
            surface: root
            name: "4th stop"
            icon: "cursor"

            Dropdown {
                id: slot4Drop
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot4
                onChipClicked: slot4Drop.open = !slot4Drop.open
                onPicked: (v) => Flags.cycleSlot4 = v
            }
        }

        SettingsRow {
            id: slot5Row
            surface: root
            name: "5th stop"
            icon: "cursor"
            last: true

            Dropdown {
                id: slot5Drop
                s: root.s
                options: root.cycleChoices
                value: Flags.cycleSlot5
                onChipClicked: slot5Drop.open = !slot5Drop.open
                onPicked: (v) => Flags.cycleSlot5 = v
            }
        }
    }
}
