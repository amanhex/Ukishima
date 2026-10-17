pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 右 RIGHT-CLICK sub-surface: the two stops the bar's right-click walk leaves to
 * the user. Stops 1-3 are fixed — the collapsed pill, the media surface and the
 * timer — so these two cards pick shell stops 4 and 5, and Off drops one from
 * the walk. Reached from INTERFACE and folds back to it on the back chevron or
 * an empty click.
 *
 * Each slot is a wrapped wall of option chips rather than a dropdown: every
 * surface is visible at once, nothing floats outside the pill, and picking one
 * is a single tap. The two cards are registered as `seg` rows so the arrow keys
 * still walk the slots and step a slot's value, same as any other settings page.
 */
SettingsSurface {
    id: root

    backSurface: "interface"
    implicitHeight: content.implicitHeight

    /**
     * The surfaces these stops can name, as one list so the chip wall and the
     * keyboard's seg cycling can never disagree. The colour-theme pages and the
     * lock page are absent: they are doors into settings rather than things to
     * pop up, and media and timer are already fixed as stops 2 and 3.
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
        { label: "Sysmon", value: "sysmon" },
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
        { item: card4, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot4; }, set: function (v) { Flags.cycleSlot4 = v; } },
        { item: card5, kind: "seg", vals: root.cycleVals, get: function () { return Flags.cycleSlot5; }, set: function (v) { Flags.cycleSlot5 = v; } }
    ]

    /** One option chip: a pill that lights vermilion while it is the picked one. */
    component ChoiceChip: Rectangle {
        id: chip

        required property string value
        required property string label
        required property bool active

        signal picked(string value)

        width: chipText.implicitWidth + 16 * root.s
        height: chipText.implicitHeight + 9 * root.s
        radius: height / 2
        color: chip.active ? Qt.alpha(Theme.vermLit, 0.20)
             : (chipArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.12) : Theme.tileBg)
        border.width: 1
        border.color: chip.active ? Qt.alpha(Theme.vermLit, 0.60)
                    : (chipArea.containsMouse ? Theme.hairSoft : Theme.border)

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? Theme.vermLit : Theme.cream
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: chip.active ? Font.Bold : Font.DemiBold

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.picked(chip.value)
        }
    }

    /** A titled card wrapping the chips of one stop. */
    component SectionCard: Rectangle {
        id: card

        property string title: ""
        property var options: []
        property string value: ""
        property bool focused: false

        signal picked(string value)

        width: parent.width
        height: body.implicitHeight + 20 * root.s
        radius: 13 * root.s
        color: Theme.cardBot

        HoverHandler {
            onHoveredChanged: root.reportRowHover(card, hovered)
        }

        Column {
            id: body
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 11 * root.s
            anchors.leftMargin: 13 * root.s
            anchors.rightMargin: 13 * root.s
            spacing: 9 * root.s

            Text {
                id: cardCaption
                text: card.title
                color: card.focused ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.3 * root.s
            }

            Flow {
                id: flow
                width: parent.width
                spacing: 6 * root.s

                Repeater {
                    model: card.options
                    ChoiceChip {
                        required property var modelData
                        value: modelData.value
                        label: modelData.label
                        active: card.value === modelData.value
                        onPicked: (v) => card.picked(v)
                    }
                }
            }
        }
    }

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

        SectionCard {
            id: card4
            title: "4th stop"
            options: root.cycleChoices
            value: Flags.cycleSlot4
            focused: root.focusRowItem === card4
            onPicked: (v) => Flags.cycleSlot4 = v
        }

        Item { width: 1; height: 10 * root.s }

        SectionCard {
            id: card5
            title: "5th stop"
            options: root.cycleChoices
            value: Flags.cycleSlot5
            focused: root.focusRowItem === card5
            onPicked: (v) => Flags.cycleSlot5 = v
        }
    }
}
