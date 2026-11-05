pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"
import "../../lib/scratch.js" as ScratchNav

/**
 * Chaldea "Index": a side index selects a note while the right column previews
 * it — number, title, lead line and opening prose — so the shelf can be read
 * without opening anything. Enter or a click on the preview opens the shared
 * editor. `host` is Scratchpad.
 */
Item {
    id: indexStyle

    property var host: null
    readonly property real s: indexStyle.host ? indexStyle.host.s : 1
    readonly property color line: Theme.border
    readonly property var notes: Scratch.notes
    readonly property real indexW: 170 * indexStyle.s
    readonly property var picked: notes[idx.currentIndex] ?? null

    function locateCurrent() {
        idx.currentIndex = ScratchNav.locate(notes, Scratch.currentSlug, idx.currentIndex);
    }

    function focusList() { idx.forceActiveFocus(); }

    function openPicked() {
        ScratchNav.open(indexStyle.host, notes, idx.currentIndex);
    }

    Component.onCompleted: {
        locateCurrent();
        idx.forceActiveFocus();
    }

    Connections {
        target: Scratch
        function onNotesChanged() { indexStyle.locateCurrent(); }
    }

    ScratchHeader {
        id: head
        width: parent.width
        host: indexStyle.host
        wordmark: "QUICK NOTES"
        trailing: Flags.showGlyphs ? "━ メモ" : ""
        onNewNote: indexStyle.host.openCreate()
    }

    Rectangle {
        anchors.top: head.bottom
        anchors.topMargin: 7 * indexStyle.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: indexStyle.line
    }

    Item {
        id: indexPanel
        anchors.top: head.bottom
        anchors.topMargin: 12 * indexStyle.s
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * indexStyle.s
        width: indexStyle.indexW

        Text {
            id: indexLabel
            anchors.left: parent.left
            anchors.top: parent.top
            text: "INDEX / " + String(indexStyle.notes.length).padStart(2, "0")
            color: Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8 * indexStyle.s
            font.letterSpacing: 0.7
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.top: indexLabel.bottom
            anchors.topMargin: 6 * indexStyle.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
        }

        ListView {
            id: idx
            anchors.top: indexLabel.bottom
            anchors.topMargin: 10 * indexStyle.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            focus: true
            spacing: 3 * indexStyle.s
            boundsBehavior: Flickable.StopAtBounds
            model: indexStyle.notes

            Keys.onUpPressed: decrementCurrentIndex()
            Keys.onDownPressed: incrementCurrentIndex()
            Keys.onReturnPressed: indexStyle.openPicked()
            Keys.onEnterPressed: indexStyle.openPicked()
            Keys.onSpacePressed: indexStyle.openPicked()
            Keys.onEscapePressed: indexStyle.host.requestClose()

            delegate: Item {
                id: slot
                required property int index
                required property var modelData
                width: idx.width
                height: 36 * indexStyle.s

                HoverHandler { id: hover }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: idx.currentIndex = slot.index
                    onClicked: idx.currentIndex = slot.index
                    onDoubleClicked: indexStyle.openPicked()
                }

                Rectangle {
                    anchors.fill: parent
                    color: idx.currentIndex === slot.index ? Qt.alpha(Theme.vermLit, 0.10)
                        : hover.hovered ? Qt.alpha(Theme.cream, 0.04) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2 * indexStyle.s
                    visible: idx.currentIndex === slot.index
                    color: Theme.vermLit
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 11 * indexStyle.s
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * indexStyle.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(slot.index + 1).padStart(2, "0") + " // " + (slot.modelData.title ?? "")
                    color: idx.currentIndex === slot.index ? Theme.cream : Theme.subtle
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: 9 * indexStyle.s
                    font.letterSpacing: 0.4
                }
            }
        }

        WheelScroller {
            anchors.fill: idx
            s: indexStyle.s
            flick: idx
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: indexStyle.line
        }
    }

    Item {
        id: preview
        anchors.top: head.bottom
        anchors.topMargin: 12 * indexStyle.s
        anchors.left: indexPanel.right
        anchors.leftMargin: 18 * indexStyle.s
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * indexStyle.s

        readonly property bool empty: indexStyle.picked === null
        readonly property var note: indexStyle.picked

        MouseArea {
            anchors.fill: parent
            enabled: !preview.empty
            cursorShape: Qt.PointingHandCursor
            onClicked: indexStyle.openPicked()
        }

        Text {
            id: noteNo
            text: preview.empty ? "NOTE --" : "NOTE " + String(idx.currentIndex + 1).padStart(2, "0")
            color: Theme.vermLit
            font.family: Theme.fontMono
            font.pixelSize: 8 * indexStyle.s
            font.letterSpacing: 1
            font.features: { "tnum": 1 }
        }

        Text {
            id: noteTitle
            anchors.top: noteNo.bottom
            anchors.topMargin: 7 * indexStyle.s
            anchors.left: parent.left
            anchors.right: parent.right
            text: preview.empty ? "no note selected" : (preview.note.title ?? "")
            color: preview.empty ? Theme.faint : Theme.cream
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: 14 * indexStyle.s
            font.weight: Font.DemiBold
        }

        Row {
            id: noteMeta
            anchors.top: noteTitle.bottom
            anchors.topMargin: 5 * indexStyle.s
            anchors.left: parent.left
            spacing: 8 * indexStyle.s
            visible: !preview.empty

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: preview.note && preview.note.pinned === true
                width: 8 * indexStyle.s
                height: 8 * indexStyle.s
                name: "pin"
                stroke: 1.8
                color: Theme.vermLit
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: preview.note ? (preview.note.age ?? "") + " · " + (preview.note.sizeLabel ?? "") : ""
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 8 * indexStyle.s
                font.features: { "tnum": 1 }
            }
        }

        Rectangle {
            id: previewRule
            anchors.top: noteMeta.bottom
            anchors.topMargin: 9 * indexStyle.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
        }

        Text {
            id: noteBody
            visible: !preview.empty
            anchors.top: previewRule.bottom
            anchors.topMargin: 9 * indexStyle.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: openHint.top
            anchors.bottomMargin: 8 * indexStyle.s
            text: preview.note ? (preview.note.preview ?? "") : ""
            color: Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 9.5 * indexStyle.s
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 20
        }

        Text {
            id: openHint
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: "↵  OPEN IN EDITOR"
            color: Theme.vermLit
            font.family: Theme.fontMono
            font.pixelSize: 8 * indexStyle.s
            font.letterSpacing: 0.8
            visible: !preview.empty
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "del removes · esc closes"
            color: Qt.alpha(Theme.faint, 0.7)
            font.family: Theme.fontMono
            font.pixelSize: 8 * indexStyle.s
        }
    }

    Keys.onDeletePressed: if (indexStyle.picked) Scratch.remove(indexStyle.picked.slug)
}
