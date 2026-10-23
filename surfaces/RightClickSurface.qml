pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 右 RIGHT-CLICK sub-surface: the two stops the bar's right-click walk leaves to
 * the user. Stops 1-3 are fixed — the collapsed pill, the media surface and the
 * timer — so these two rows pick shell stops 4 and 5, and Off drops one from the
 * walk. Reached from INTERFACE and folds back to it on the back chevron or an
 * empty click.
 *
 * Each row is an ordinary `Dropdown`, so its choice opens the same centred
 * picker as every other selector in the shell. The rows are registered as `seg`
 * so the arrow keys still walk them and step a value in place.
 */
SettingsSurface {
    id: root

    backSurface: "interface"
    implicitHeight: content.implicitHeight

    /**
     * The surfaces these stops can name, as one list so the picker and the
     * keyboard's seg cycling can never disagree. The colour-theme pages and the
     * lock page are absent: they are doors into settings rather than stops, and
     * `icon` is the glyph the centred picker draws beside each name.
     */
    readonly property var cycleChoices: [
        { label: "Off", value: "", icon: "close" },
        { label: "Calendar", value: "calendar", icon: "clock" },
        { label: "Weather", value: "weather", icon: "cloud" },
        { label: "Launcher", value: "launcher", icon: "app-window" },
        { label: "Clipboard", value: "clipboard", icon: "clipboard" },
        { label: "Emoji", value: "emoji", icon: "emoji" },
        { label: "Scratchpad", value: "scratch", icon: "type" },
        { label: "Wallpaper", value: "wallpaper", icon: "wallpaper" },
        { label: "Power", value: "power", icon: "shutdown" },
        { label: "Mixer", value: "mixer", icon: "mixer" },
        { label: "Link", value: "link", icon: "inbox" },
        { label: "Wi-Fi", value: "wifi", icon: "wifi" },
        { label: "Bluetooth", value: "bt", icon: "bluetooth" },
        { label: "Battery", value: "battery", icon: "bolt" },
        { label: "Recorder", value: "recorder", icon: "video" },
        { label: "Sysmon", value: "sysmon", icon: "monitor" },
        { label: "Appearance", value: "appearance", icon: "palette" },
        { label: "Profile", value: "profile", icon: "user" }
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

        SettingsRow {
            id: slot4Row
            surface: root
            icon: "cursor"
            name: "4th stop"

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
            icon: "cursor"
            name: "5th stop"
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
