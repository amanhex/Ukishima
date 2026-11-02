pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Rail": a thin console strip. Header line with the source and live
 * status, a hairline, then artwork + track readout with the transport chipped
 * in on the right, and a bottom line holding the source picker and the seek.
 * `host` is the Media surface (data, actions, scale).
 */
Item {
    id: rail

    property var host: null
    readonly property real s: rail.host ? rail.host.s : 1
    readonly property real pad: 14 * rail.s
    readonly property color line: Theme.border
    readonly property color red: Theme.accent
    readonly property color ink: Theme.cream
    readonly property color dim: Theme.subtle

    Text {
        id: head
        anchors.top: parent.top
        anchors.topMargin: rail.pad
        anchors.left: parent.left
        anchors.leftMargin: rail.pad
        anchors.right: statusRow.left
        anchors.rightMargin: 8 * rail.s
        text: "AUDIO // " + (rail.host ? rail.host.serviceLabel : "OFFLINE")
        color: rail.dim
        elide: Text.ElideRight
        font.family: Theme.fontMono
        font.pixelSize: 8.5 * rail.s
    }

    MediaStatus {
        id: statusRow
        anchors.top: parent.top
        anchors.topMargin: rail.pad - 1 * rail.s
        anchors.right: parent.right
        anchors.rightMargin: rail.pad
        host: rail.host
        compact: true
    }

    Rectangle {
        id: hairline
        anchors.top: head.bottom
        anchors.topMargin: 5 * rail.s
        anchors.left: parent.left
        anchors.leftMargin: rail.pad
        anchors.right: parent.right
        anchors.rightMargin: rail.pad
        height: 1
        color: rail.line
    }

    Item {
        id: body
        anchors.top: hairline.bottom
        anchors.topMargin: 8 * rail.s
        anchors.left: parent.left
        anchors.leftMargin: rail.pad
        anchors.right: parent.right
        anchors.rightMargin: rail.pad
        anchors.bottom: bottom.top
        anchors.bottomMargin: 8 * rail.s

        MediaArt {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: 74 * rail.s
            height: 74 * rail.s
            host: rail.host
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 10 * rail.s
            anchors.right: chips.left
            anchors.rightMargin: 10 * rail.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * rail.s

            Text {
                text: (rail.host ? rail.host.trackNo : "--") + " // TRACK"
                color: rail.red
                font.family: Theme.fontMono
                font.pixelSize: 8 * rail.s
            }

            Marquee {
                width: parent.width
                text: rail.host ? rail.host.title : ""
                color: rail.ink
                pixelSize: 14 * rail.s
                weight: Font.DemiBold
                fontFamily: Theme.fontMono
                active: rail.host ? rail.host.active : false
            }

            Marquee {
                width: parent.width
                height: rail.host && rail.host.sub.length > 0 ? implicitHeight : 0
                text: rail.host ? rail.host.sub : ""
                color: rail.dim
                pixelSize: 9.5 * rail.s
                fontFamily: Theme.fontMono
                active: rail.host ? rail.host.active : false
            }
        }

        MediaTransport {
            id: chips
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: rail.host
            compact: true
        }
    }

    Item {
        id: bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rail.pad
        anchors.left: parent.left
        anchors.leftMargin: rail.pad
        anchors.right: parent.right
        anchors.rightMargin: rail.pad
        height: 14 * rail.s

        MediaSources {
            id: sources
            width: 88 * rail.s
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            host: rail.host
        }

        MediaSeek {
            anchors.left: sources.right
            anchors.leftMargin: 8 * rail.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: rail.host
        }
    }
}
