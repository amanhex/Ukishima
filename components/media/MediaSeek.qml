pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"
import "../../lib/format.js" as Fmt

/**
 * Transport seek line for the Chaldea-style media designs: tick ruler (optional),
 * a flat red progress bar with drag-to-seek, position/duration, and the loop
 * chip that still walks None -> Track -> Playlist. `host` is the Media surface.
 */
Item {
    id: seek

    property var host: null
    property bool ruler: false
    readonly property real s: seek.host ? seek.host.s : 1
    readonly property bool canSeek: seek.host
        && seek.host.hasPlayer
        && seek.host.player
        && seek.host.player.canSeek
        && seek.host.player.positionSupported
        && seek.host.lengthSec > 0
        && !seek.host.live
    implicitHeight: (seek.ruler ? 7 * seek.s : 0) + 14 * seek.s

    /** Tick ruler (Chaldea's Matrix and Title designs). */
    Row {
        id: rulerRow
        visible: seek.ruler
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 5 * seek.s
        spacing: (width - 33) / 32

        Repeater {
            model: 33
            delegate: Rectangle {
                required property int index
                width: 1
                height: (index % 5 === 0 ? 5 : 3) * seek.s
                color: "#68605a"
            }
        }
    }

    Item {
        id: barRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 12 * seek.s

        Text {
            id: pos
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Fmt.fmtDuration(seek.host
                ? (seek.host.dragging ? seek.host.dragFrac * seek.host.lengthSec : seek.host.positionSec)
                : 0)
            color: "#a09b96"
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * seek.s
            font.features: { "tnum": 1 }
        }

        Item {
            id: loopBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * seek.s
            height: 13 * seek.s
            visible: seek.host ? seek.host.loopOk : false
            opacity: seek.host && seek.host.loopNone ? 0.45 : 1

            Rectangle {
                anchors.fill: parent
                color: loopArea.containsMouse ? "#1a1a1a" : "transparent"
                border.width: 1
                border.color: seek.host && !seek.host.loopNone
                    ? (seek.host.loopNone ? "transparent" : "#cc1515")
                    : "transparent"
            }

            Text {
                visible: Flags.showGlyphs
                anchors.centerIn: parent
                text: "循"
                color: seek.host && seek.host.loopNone ? "#68605a" : "#cc1515"
                font.family: Theme.fontJp
                font.pixelSize: 10 * seek.s
            }

            GlyphIcon {
                visible: !Flags.showGlyphs
                anchors.centerIn: parent
                width: 10 * seek.s
                height: 10 * seek.s
                name: "refresh"
                color: seek.host && seek.host.loopNone ? "#68605a" : "#cc1515"
            }

            Rectangle {
                visible: seek.host ? seek.host.loopTrack : false
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -1 * seek.s
                anchors.rightMargin: -1 * seek.s
                width: 3 * seek.s
                height: 3 * seek.s
                color: "#cc1515"
            }

            MouseArea {
                id: loopArea
                anchors.fill: parent
                anchors.margins: -4 * seek.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (seek.host) seek.host.nextLoop()
            }
        }

        Text {
            id: dur
            anchors.right: loopBox.visible ? loopBox.left : parent.right
            anchors.rightMargin: loopBox.visible ? 6 * seek.s : 0
            anchors.verticalCenter: parent.verticalCenter
            text: seek.host && seek.host.live ? "LIVE"
                : (seek.host && seek.host.lengthSec > 0 ? Fmt.fmtDuration(seek.host.lengthSec) : "--:--")
            color: "#a09b96"
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * seek.s
            font.features: { "tnum": 1 }
        }

        Item {
            id: track
            anchors.left: pos.right
            anchors.leftMargin: 6 * seek.s
            anchors.right: dur.left
            anchors.rightMargin: 6 * seek.s
            anchors.verticalCenter: parent.verticalCenter
            height: 12 * seek.s

            readonly property real progress: seek.host
                ? Math.max(0, Math.min(1, seek.host.dragging ? seek.host.dragFrac : seek.host.frac))
                : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2 * seek.s
                color: "#403a36"
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * parent.progress
                height: 2 * seek.s
                color: "#cc1515"
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * parent.progress))
                width: 2 * seek.s
                height: 9 * seek.s
                color: seek.canSeek ? "#e8e8e8" : "#68605a"
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * seek.s
                enabled: seek.canSeek
                cursorShape: Qt.PointingHandCursor

                function fracAt(mx) {
                    var x = mx - 6 * seek.s;
                    return Math.max(0, Math.min(1, x / Math.max(1, track.width)));
                }

                onPressed: (e) => {
                    if (!seek.host)
                        return;
                    seek.host.dragFrac = fracAt(e.x);
                    seek.host.dragging = true;
                }
                onPositionChanged: (e) => {
                    if (pressed && seek.host)
                        seek.host.dragFrac = fracAt(e.x);
                }
                onReleased: {
                    if (seek.host && seek.host.player)
                        seek.host.player.position = seek.host.dragFrac * seek.host.lengthSec;
                    if (seek.host)
                        seek.host.dragging = false;
                }
            }
        }
    }
}
