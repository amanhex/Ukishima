pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"
import "../../lib/scratch.js" as ScratchNav

/**
 * Chaldea "Cassette": the pad as a drawer list — numbered note rows under a
 * mono wordmark, with the pin, age and first line inline. Enter or a click
 * opens the shared note editor; Delete removes the highlighted row. `host` is
 * Scratchpad.
 */
Item {
    id: cassette

    property var host: null
    readonly property real s: cassette.host ? cassette.host.s : 1
    readonly property color line: Theme.border
    readonly property var notes: Scratch.notes

    readonly property string summary: notes.length === 0 ? "nothing written down yet"
        : notes.length + (notes.length === 1 ? " note" : " notes")

    function locateCurrent() {
        list.currentIndex = ScratchNav.locate(notes, Scratch.currentSlug, list.currentIndex);
    }

    function focusList() { list.forceActiveFocus(); }

    function openCurrent() {
        ScratchNav.open(cassette.host, notes, list.currentIndex);
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
        function onNotesChanged() { cassette.locateCurrent(); }
    }

    ScratchHeader {
        id: head
        width: parent.width
        host: cassette.host
        wordmark: "QUICK NOTES"
        trailing: cassette.notes.length > 0 ? "A // " + String(cassette.notes.length).padStart(2, "0") : "A // 00"
        onNewNote: cassette.host.openCreate()
    }

    Rectangle {
        anchors.top: head.bottom
        anchors.topMargin: 7 * cassette.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: cassette.line
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 14 * cassette.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: foot.top
        anchors.bottomMargin: 8 * cassette.s
        clip: true
        focus: true
        spacing: 5 * cassette.s
        boundsBehavior: Flickable.StopAtBounds
        model: cassette.notes

        Keys.onUpPressed: decrementCurrentIndex()
        Keys.onDownPressed: incrementCurrentIndex()
        Keys.onReturnPressed: cassette.openCurrent()
        Keys.onEnterPressed: cassette.openCurrent()
        Keys.onSpacePressed: cassette.openCurrent()
        Keys.onDeletePressed: cassette.removeCurrent()
        Keys.onEscapePressed: cassette.host.requestClose()

        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            width: list.width
            height: 46 * cassette.s

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: list.currentIndex = slot.index
                onClicked: cassette.openCurrent()
            }

            ScratchRow {
                anchors.fill: parent
                host: cassette.host
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
        s: cassette.s
        flick: list
    }

    Text {
        anchors.centerIn: list
        visible: cassette.notes.length === 0
        text: "nothing written down yet"
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: 10 * cassette.s
        font.letterSpacing: 0.8
    }

    Item {
        id: foot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 13 * cassette.s

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "enter opens · del removes · esc closes"
            color: Qt.alpha(Theme.faint, 0.7)
            font.family: Theme.fontMono
            font.pixelSize: 8 * cassette.s
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: cassette.summary
            color: Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8 * cassette.s
            font.features: { "tnum": 1 }
        }
    }
}
