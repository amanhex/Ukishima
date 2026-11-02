pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Title": typography leads. The track name is the surface, with a
 * small sleeve thumbnail and the transport stacked at the right edge, a ruler
 * seek under it, and the live status line at the foot. `host` is Media.
 */
Item {
    id: titleStyle

    property var host: null
    readonly property real s: titleStyle.host ? titleStyle.host.s : 1
    readonly property real pad: 14 * titleStyle.s
    readonly property color line: "#34302f"
    readonly property color red: "#cc1515"
    readonly property color ink: "#e8e8e8"
    readonly property color dim: "#a09b96"

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
        anchors.topMargin: 3 * titleStyle.s
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        height: 56 * titleStyle.s

        Column {
            anchors.left: parent.left
            anchors.right: art.left
            anchors.rightMargin: 8 * titleStyle.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * titleStyle.s

            Marquee {
                width: parent.width
                text: titleStyle.host ? titleStyle.host.title : ""
                color: titleStyle.ink
                pixelSize: 22 * titleStyle.s
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

        MediaArt {
            id: art
            anchors.right: chips.left
            anchors.rightMargin: 8 * titleStyle.s
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * titleStyle.s
            height: 48 * titleStyle.s
            host: titleStyle.host
        }

        Rectangle {
            anchors.right: art.right
            anchors.top: art.top
            width: 16 * titleStyle.s
            height: 2 * titleStyle.s
            color: titleStyle.red
        }

        MediaTransport {
            id: chips
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            host: titleStyle.host
            vertical: true
            compact: true
        }
    }

    MediaSeek {
        id: seek
        anchors.top: body.bottom
        anchors.topMargin: 3 * titleStyle.s
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        host: titleStyle.host
        ruler: true
    }

    Item {
        id: foot
        anchors.bottom: parent.bottom
        anchors.bottomMargin: titleStyle.pad
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        height: 12 * titleStyle.s

        MediaStatus {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            host: titleStyle.host
            compact: true
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "SIDE A"
            color: "#68605a"
            font.family: Theme.fontMono
            font.pixelSize: 8 * titleStyle.s
            font.letterSpacing: 1
        }
    }
}
