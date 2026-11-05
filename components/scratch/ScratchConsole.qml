pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"
import "../../lib/scratch.js" as ScratchNav

/**
 * Chaldea "Console": the pad as a personal log. Mono rows behind a printed
 * band, a hairline between channels, and the entry count at the top right.
 * Enter opens the shared editor, Delete removes the entry. `host` is Scratchpad.
 */
Item {
    id: logPad

    property var host: null
    readonly property real s: logPad.host ? logPad.host.s : 1
    readonly property color line: Theme.border
    readonly property var notes: Scratch.notes

    function locateCurrent() {
        list.currentIndex = ScratchNav.locate(notes, Scratch.currentSlug, list.currentIndex);
    }

    function focusList() { list.forceActiveFocus(); }

    function openCurrent() {
        ScratchNav.open(logPad.host, notes, list.currentIndex);
    }

    function removeCurrent() {
        ScratchNav.remove(Scratch, notes, list.currentIndex);
    }

    Component.onCompleted: {
        locateCurrent();
        list.forceActiveFocus();
    }

    Connections {
        target: Scratch
        function onNotesChanged() { logPad.locateCurrent(); }
    }

    Item {
        id: band
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 20 * logPad.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "TSUGUMORI // PERSONAL LOG"
            color: Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * logPad.s
            font.letterSpacing: 0.8
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * logPad.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String(logPad.notes.length).padStart(3, "0") + " ENTRIES"
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 8 * logPad.s
                font.letterSpacing: 0.6
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "+ NEW"
                color: newArea.containsMouse ? Theme.vermLit : Theme.subtle
                font.family: Theme.fontMono
                font.pixelSize: 8 * logPad.s
                font.letterSpacing: 0.8

                MouseArea {
                    id: newArea
                    anchors.fill: parent
                    anchors.margins: -5 * logPad.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: logPad.host.openCreate()
                }
            }
        }
    }

    Rectangle {
        anchors.top: band.bottom
        anchors.topMargin: 5 * logPad.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: logPad.line
    }

    ListView {
        id: list
        anchors.top: band.bottom
        anchors.topMargin: 11 * logPad.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.bottomMargin: 8 * logPad.s
        clip: true
        focus: true
        spacing: 2 * logPad.s
        boundsBehavior: Flickable.StopAtBounds
        model: logPad.notes

        Keys.onUpPressed: decrementCurrentIndex()
        Keys.onDownPressed: incrementCurrentIndex()
        Keys.onReturnPressed: logPad.openCurrent()
        Keys.onEnterPressed: logPad.openCurrent()
        Keys.onSpacePressed: logPad.openCurrent()
        Keys.onDeletePressed: logPad.removeCurrent()
        Keys.onEscapePressed: logPad.host.requestClose()

        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            width: list.width
            height: 33 * logPad.s

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: list.currentIndex = slot.index
                onClicked: logPad.openCurrent()
            }

            ScratchRow {
                anchors.fill: parent
                host: logPad.host
                numbered: true
                monoTitle: true
                marker: false
                number: slot.index + 1
                title: slot.modelData.title ?? ""
                preview: slot.modelData.preview ?? ""
                age: slot.modelData.age ?? ""
                pinned: slot.modelData.pinned === true
                selected: list.currentIndex === slot.index
                hovered: hover.hovered
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.hairSoft
            }
        }
    }

    WheelScroller {
        anchors.fill: list
        s: logPad.s
        flick: list
    }

    Text {
        anchors.centerIn: list
        visible: logPad.notes.length === 0
        text: "// no entries"
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: 10 * logPad.s
    }

    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 13 * logPad.s

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: -5 * logPad.s
            height: 1
            color: logPad.line
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "LOCAL DISK · MARKDOWN"
            color: Qt.alpha(Theme.faint, 0.75)
            font.family: Theme.fontMono
            font.pixelSize: 8 * logPad.s
            font.letterSpacing: 0.5
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "↵ OPEN · DEL REMOVE · ESC CLOSE"
            color: Qt.alpha(Theme.faint, 0.7)
            font.family: Theme.fontMono
            font.pixelSize: 8 * logPad.s
        }
    }
}
