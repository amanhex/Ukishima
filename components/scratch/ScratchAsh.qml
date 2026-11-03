pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Ash": the pad as a stack of memo cards. One card expands to show its
 * opening prose; the expanded card opens the shared editor on a second click or
 * Enter. New sits in the header band. `host` is Scratchpad.
 */
Item {
    id: ash

    property var host: null
    readonly property real s: ash.host ? ash.host.s : 1
    readonly property color line: Theme.border
    readonly property var notes: Scratch.notes
    property int expandedIndex: -1

    function focusList() { stack.forceActiveFocus(); }

    function locateCurrent() {
        for (var i = 0; i < notes.length; i++)
            if (notes[i].slug === Scratch.currentSlug) {
                ash.expandedIndex = i;
                return;
            }
        if (ash.expandedIndex < 0 && ash.notes.length > 0)
            ash.expandedIndex = 0;
    }

    function openCurrent() {
        var note = notes[ash.expandedIndex];
        if (!note) {
            ash.host.openCreate();
            return;
        }
        ash.host.openNote(note.slug);
    }

    function removeCurrent() {
        var note = notes[ash.expandedIndex];
        if (note)
            Scratch.remove(note.slug);
    }

    function move(step) {
        if (ash.notes.length === 0)
            return;
        ash.expandedIndex = Math.max(0, Math.min(ash.notes.length - 1, ash.expandedIndex + step));
    }

    Component.onCompleted: locateCurrent()

    Connections {
        target: Scratch
        function onNotesChanged() { ash.locateCurrent(); }
    }

    Item {
        id: band
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * ash.s

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3 * ash.s
            color: Theme.vermLit
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12 * ash.s
            anchors.verticalCenter: parent.verticalCenter
            text: "QUICK NOTES"
            color: Theme.vermLit
            font.family: Theme.fontMono
            font.pixelSize: 10 * ash.s
            font.letterSpacing: 1.6
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * ash.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String(ash.notes.length).padStart(2, "0") + " CARDS"
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 8 * ash.s
                font.letterSpacing: 0.6
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+ NEW"
                color: newArea.containsMouse ? Theme.vermLit : Theme.subtle
                font.family: Theme.fontMono
                font.pixelSize: 8 * ash.s
                font.letterSpacing: 0.8

                MouseArea {
                    id: newArea
                    anchors.fill: parent
                    anchors.margins: -5 * ash.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ash.host.openCreate()
                }
            }
        }
    }

    Rectangle {
        anchors.top: band.bottom
        anchors.topMargin: 5 * ash.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    ListView {
        id: stack
        anchors.top: band.bottom
        anchors.topMargin: 11 * ash.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.bottomMargin: 8 * ash.s
        clip: true
        focus: true
        spacing: 6 * ash.s
        boundsBehavior: Flickable.StopAtBounds
        model: ash.notes

        Keys.onUpPressed: ash.move(-1)
        Keys.onDownPressed: ash.move(1)
        Keys.onReturnPressed: ash.openCurrent()
        Keys.onEnterPressed: ash.openCurrent()
        Keys.onSpacePressed: ash.openCurrent()
        Keys.onDeletePressed: ash.removeCurrent()
        Keys.onEscapePressed: ash.host.requestClose()

        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            readonly property bool expanded: ash.expandedIndex === slot.index
            width: stack.width
            height: (slot.expanded ? 102 : 44) * ash.s

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (slot.expanded)
                        ash.openCurrent();
                    else
                        ash.expandedIndex = slot.index;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: slot.expanded ? Theme.cardBot
                    : hover.hovered ? Qt.alpha(Theme.cream, 0.03) : "transparent"
                border.width: 1
                border.color: slot.expanded ? Theme.vermLit
                    : hover.hovered ? Theme.border : Theme.hairSoft
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3 * ash.s
                color: Theme.vermLit
                opacity: slot.expanded ? 1 : 0.35
            }

            Text {
                id: kicker
                anchors.left: parent.left
                anchors.leftMargin: 13 * ash.s
                anchors.top: parent.top
                anchors.topMargin: 7 * ash.s
                text: "PERSONAL NOTE"
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 7.5 * ash.s
                font.letterSpacing: 1
            }

            Text {
                id: title
                anchors.left: kicker.right
                anchors.leftMargin: 7 * ash.s
                anchors.right: age.left
                anchors.rightMargin: 8 * ash.s
                anchors.top: parent.top
                anchors.topMargin: 5 * ash.s
                text: slot.modelData.title ?? ""
                color: Theme.cream
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 11.5 * ash.s
                font.weight: Font.DemiBold
            }

            Row {
                id: age
                anchors.right: parent.right
                anchors.rightMargin: 12 * ash.s
                anchors.top: parent.top
                anchors.topMargin: 7 * ash.s
                spacing: 6 * ash.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: slot.modelData.pinned === true
                    width: 8 * ash.s
                    height: 8 * ash.s
                    name: "pin"
                    stroke: 1.8
                    color: Theme.vermLit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (slot.modelData.age ?? "") + "   " + (slot.expanded ? "−" : "+")
                    color: slot.expanded ? Theme.vermLit : Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 8.5 * ash.s
                    font.features: { "tnum": 1 }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 13 * ash.s
                anchors.right: parent.right
                anchors.rightMargin: 12 * ash.s
                anchors.top: parent.top
                anchors.topMargin: 25 * ash.s
                height: 1
                color: slot.expanded ? Theme.border : Theme.hairSoft
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13 * ash.s
                anchors.right: parent.right
                anchors.rightMargin: 12 * ash.s
                anchors.top: parent.top
                anchors.topMargin: 30 * ash.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8 * ash.s
                text: slot.modelData.preview && slot.modelData.preview.length > 0
                    ? slot.modelData.preview : "empty"
                color: slot.modelData.preview ? Theme.subtle : Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 9 * ash.s
                lineHeight: 1.3
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: slot.expanded ? 5 : 1
            }

            Text {
                visible: slot.expanded
                anchors.left: parent.left
                anchors.leftMargin: 13 * ash.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6 * ash.s
                text: "EDIT NOTE"
                color: Theme.vermLit
                font.family: Theme.fontMono
                font.pixelSize: 7.5 * ash.s
                font.letterSpacing: 1
            }
        }
    }

    WheelScroller {
        anchors.fill: stack
        s: ash.s
        flick: stack
    }

    Text {
        anchors.centerIn: stack
        visible: ash.notes.length === 0
        text: "no cards yet"
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: 10 * ash.s
        font.letterSpacing: 0.8
    }

    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 12 * ash.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "MARKDOWN ON LOCAL DISK"
            color: Qt.alpha(Theme.faint, 0.75)
            font.family: Theme.fontMono
            font.pixelSize: 7.5 * ash.s
            font.letterSpacing: 0.5
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "click expands · enter edits · del removes"
            color: Qt.alpha(Theme.faint, 0.7)
            font.family: Theme.fontMono
            font.pixelSize: 7.5 * ash.s
        }
    }
}
