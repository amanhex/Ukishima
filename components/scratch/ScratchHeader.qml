pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea-style header for the scratchpad deck designs: the 記 tag, a mono
 * wordmark, a trailing count and a NEW button. `host` is Scratchpad.
 */
Item {
    id: head

    property var host: null
    property string tag: "記"
    property string wordmark: "QUICK NOTES"
    property string trailing: ""
    property string newLabel: "+ NEW"
    readonly property real s: head.host ? head.host.s : 1
    signal newNote()

    implicitHeight: 22 * head.s

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * head.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.showGlyphs
            text: head.tag
            color: Theme.vermLit
            font.family: Theme.fontJp
            font.weight: Theme.fontJpWeight
            font.pixelSize: 14 * head.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: head.wordmark
            color: Theme.cream
            font.family: Theme.fontMono
            font.pixelSize: 9 * head.s
            font.letterSpacing: 1.4
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10 * head.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: head.trailing
            color: Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * head.s
            font.letterSpacing: 0.6
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: newText.implicitWidth + 16 * head.s
            height: 20 * head.s
            color: newArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.16) : Qt.alpha(Theme.cream, 0.05)
            border.width: 1
            border.color: newArea.containsMouse ? Theme.vermLit : Theme.border

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                id: newText
                anchors.centerIn: parent
                text: head.newLabel
                color: newArea.containsMouse ? Theme.vermLit : Theme.subtle
                font.family: Theme.fontMono
                font.pixelSize: 8 * head.s
                font.letterSpacing: 0.8
            }

            MouseArea {
                id: newArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: head.newNote()
            }
        }
    }
}
