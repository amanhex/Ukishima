pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Title": typography leads. A small wordmark rule and source picker
 * sit at the head, the track and artist take the full left half, the cover
 * holds the right corner, and the transport and live reads share the foot.
 * Keeping the cover and the transport on opposite ends is what stops the card
 * from crowding. `host` is Media.
 */
Item {
    id: titleStyle

    property var host: null
    readonly property real s: titleStyle.host ? titleStyle.host.s : 1
    readonly property real pad: 16 * titleStyle.s
    readonly property color line: Theme.border
    readonly property color red: Theme.vermLit
    readonly property color ink: Theme.cream
    readonly property color dim: Theme.subtle

    Item {
        id: header
        anchors.top: parent.top
        anchors.topMargin: titleStyle.pad
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        height: 12 * titleStyle.s

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3 * titleStyle.s
            height: 9 * titleStyle.s
            color: titleStyle.red
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 7 * titleStyle.s
            anchors.right: sources.left
            anchors.rightMargin: 8 * titleStyle.s
            anchors.verticalCenter: parent.verticalCenter
            text: "TSUGUMORI // AUDIO"
            color: titleStyle.ink
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * titleStyle.s
            font.letterSpacing: 1
        }

        MediaSources {
            id: sources
            width: 90 * titleStyle.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: titleStyle.host
        }
    }

    Rectangle {
        id: hairline
        anchors.top: header.bottom
        anchors.topMargin: 3 * titleStyle.s
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        height: 1
        color: titleStyle.line
    }

    Item {
        id: body
        anchors.top: hairline.bottom
        anchors.topMargin: 5 * titleStyle.s
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        anchors.bottom: seek.top
        anchors.bottomMargin: 7 * titleStyle.s

        MediaArt {
            id: art
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 58 * titleStyle.s
            height: 58 * titleStyle.s
            host: titleStyle.host
            lineColor: Theme.faint
        }

        Rectangle {
            anchors.right: art.right
            anchors.top: art.top
            width: 18 * titleStyle.s
            height: 2 * titleStyle.s
            color: titleStyle.red
        }

        Column {
            anchors.left: parent.left
            anchors.right: art.left
            anchors.rightMargin: 24 * titleStyle.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * titleStyle.s

            Text {
                text: "TRK " + (titleStyle.host ? titleStyle.host.trackNo : "--")
                    + " // " + (titleStyle.host ? titleStyle.host.status : "IDLE")
                color: titleStyle.red
                font.family: Theme.fontMono
                font.pixelSize: 8 * titleStyle.s
                font.letterSpacing: 0.6
            }

            Marquee {
                width: parent.width
                text: titleStyle.host ? titleStyle.host.title : ""
                color: titleStyle.ink
                pixelSize: 16 * titleStyle.s
                weight: Font.DemiBold
                fontFamily: Theme.fontMono
                active: titleStyle.host ? titleStyle.host.active : false
            }

            Marquee {
                width: parent.width
                text: titleStyle.host ? titleStyle.host.sub : ""
                color: titleStyle.dim
                pixelSize: 9.5 * titleStyle.s
                fontFamily: Theme.fontMono
                active: titleStyle.host ? titleStyle.host.active : false
                visible: text.length > 0
            }
        }
    }

    MediaSeek {
        id: seek
        anchors.bottom: foot.top
        anchors.bottomMargin: 10 * titleStyle.s
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        host: titleStyle.host
    }

    Item {
        id: foot
        anchors.bottom: parent.bottom
        anchors.bottomMargin: titleStyle.pad
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        height: 18 * titleStyle.s

        MediaTransport {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            host: titleStyle.host
            compact: true
        }

        MediaStatus {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: titleStyle.host
            compact: true
        }
    }
}