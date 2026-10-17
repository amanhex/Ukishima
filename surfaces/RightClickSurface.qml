pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 右 RIGHT-CLICK sub-surface: the two stops the bar's right-click walk leaves to
 * the user. Stops 1-3 are fixed — the collapsed pill, the media surface and the
 * timer — so these two sections pick shell stops 4 and 5, with Off dropping a
 * stop. Reached from INTERFACE and folds back to it on an empty click or the
 * back target. A chip flow keeps every option visible without opening a wide
 * floating dropdown.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 18
    mRight: 18
    mBottom: 15

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

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

    component ChoiceChip: Rectangle {
        id: chip

        required property string value
        required property string label
        required property bool active

        width: chipText.implicitWidth + 18 * root.s
        height: chipText.implicitHeight + 10 * root.s
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
            font.pixelSize: 10.5 * root.s
            font.weight: chip.active ? Font.Bold : Font.DemiBold

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.parent.clicked(chip.value)
        }
    }

    component SectionCard: Rectangle {
        id: card
        property string title: ""
        default property alias chips: flow.data

        width: parent.width
        height: flow.implicitHeight + 26 * root.s
        radius: 13 * root.s
        color: Theme.cardBot

        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16 * root.s
            anchors.topMargin: 11 * root.s
            text: card.title
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        Flow {
            id: flow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            anchors.bottomMargin: 10 * root.s
            spacing: 6 * root.s
            flowSpacing: 6 * root.s
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: (e) => {
            if (e.button === Qt.LeftButton)
                root.requestSurface("interface");
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "右"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Theme.fontJpWeight
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RIGHT-CLICK"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        SectionCard {
            title: "4th stop"
            property string slot: Flags.cycleSlot4
            signal clicked(string v)
            onClicked: (v) => Flags.cycleSlot4 = v

            Repeater {
                model: root.cycleChoices
                ChoiceChip {
                    required property var modelData
                    value: modelData.value
                    label: modelData.label
                    active: parent.slot === modelData.value
                }
            }
        }

        Item { width: 1; height: 10 * root.s }

        SectionCard {
            title: "5th stop"
            property string slot: Flags.cycleSlot5
            signal clicked(string v)
            onClicked: (v) => Flags.cycleSlot5 = v

            Repeater {
                model: root.cycleChoices
                ChoiceChip {
                    required property var modelData
                    value: modelData.value
                    label: modelData.label
                    active: parent.slot === modelData.value
                }
            }
        }
    }
}
