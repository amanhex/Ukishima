pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Matrix": the cover reduced to a 32x32 glyph grid, a numbered
 * readout beside it, and a ruled seek line — the terminal, hardware-panel
 * take on the player. `host` is Media.
 */
Item {
    id: matrix

    property var host: null
    readonly property real s: matrix.host ? matrix.host.s : 1
    readonly property real pad: 16 * matrix.s
    readonly property color line: Theme.border
    readonly property color red: Theme.vermLit
    readonly property color ink: Theme.cream
    readonly property color dim: Theme.subtle

    Text {
        id: head
        anchors.top: parent.top
        anchors.topMargin: matrix.pad
        anchors.left: parent.left
        anchors.leftMargin: matrix.pad
        anchors.right: statusRow.left
        anchors.rightMargin: 8 * matrix.s
        text: "NR-2B // AUDIO"
        color: matrix.red
        font.family: Theme.fontMono
        font.pixelSize: 8.5 * matrix.s
        font.letterSpacing: 1
    }

    MediaStatus {
        id: statusRow
        anchors.top: parent.top
        anchors.topMargin: matrix.pad - 1 * matrix.s
        anchors.right: parent.right
        anchors.rightMargin: matrix.pad
        host: matrix.host
        compact: true
    }

    Rectangle {
        id: hairline
        anchors.top: head.bottom
        anchors.topMargin: 4 * matrix.s
        anchors.left: parent.left
        anchors.leftMargin: matrix.pad
        anchors.right: parent.right
        anchors.rightMargin: matrix.pad
        height: 1
        color: matrix.line
    }

    Item {
        id: body
        anchors.top: hairline.bottom
        anchors.topMargin: 4 * matrix.s
        anchors.left: parent.left
        anchors.leftMargin: matrix.pad
        anchors.right: parent.right
        anchors.rightMargin: matrix.pad
        anchors.bottom: bottom.top
        anchors.bottomMargin: 4 * matrix.s

        MediaArt {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: 66 * matrix.s
            height: 66 * matrix.s
            host: matrix.host
            matrix: true
            lineColor: Qt.alpha(Theme.cream, 0.22)
        }

        Text {
            anchors.left: art.left
            anchors.bottom: art.bottom
            anchors.bottomMargin: 2 * matrix.s
            text: "GLYPH / " + (matrix.host ? matrix.host.trackNo : "--")
            color: Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 7 * matrix.s
        }

        Rectangle {
            id: bodyDivider
            anchors.left: art.right
            anchors.leftMargin: 10 * matrix.s
            y: 0
            width: 1
            height: parent.height
            color: matrix.line
        }

        Column {
            anchors.left: bodyDivider.right
            anchors.leftMargin: 11 * matrix.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * matrix.s

            Text {
                text: (matrix.host ? matrix.host.status : "IDLE") + " // " + (matrix.host ? matrix.host.serviceLabel : "OFFLINE")
                color: matrix.dim
                elide: Text.ElideRight
                width: parent.width
                font.family: Theme.fontMono
                font.pixelSize: 8.5 * matrix.s
            }

            Marquee {
                width: parent.width
                text: matrix.host ? matrix.host.title : ""
                color: matrix.ink
                pixelSize: 18 * matrix.s
                weight: Font.DemiBold
                fontFamily: Theme.fontMono
                active: matrix.host ? matrix.host.active : false
            }

            Text {
                width: parent.width
                text: matrix.host ? matrix.host.artist : ""
                color: matrix.dim
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: 9.5 * matrix.s
            }

            Text {
                width: parent.width
                text: matrix.host ? matrix.host.album : ""
                color: Theme.faint
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: 8.5 * matrix.s
            }
        }
    }

    Item {
        id: bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: matrix.pad
        anchors.left: parent.left
        anchors.leftMargin: matrix.pad
        anchors.right: parent.right
        anchors.rightMargin: matrix.pad
        height: 21 * matrix.s

        MediaSources {
            id: sources
            width: 96 * matrix.s
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            host: matrix.host
        }

        MediaSeek {
            anchors.left: sources.right
            anchors.leftMargin: 8 * matrix.s
            anchors.right: chips.left
            anchors.rightMargin: 8 * matrix.s
            anchors.verticalCenter: parent.verticalCenter
            host: matrix.host
            ruler: true
        }

        MediaTransport {
            id: chips
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: matrix.host
            compact: true
        }
    }
}
