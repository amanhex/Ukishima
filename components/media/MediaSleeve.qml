pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Sleeve": a record sleeve with a vertical spine label down the left
 * edge, the cover set against it with its red corner tick, and the track,
 * seek, transport and source chrome stacked to the right. `host` is Media.
 */
Item {
    id: sleeve

    property var host: null
    readonly property real s: sleeve.host ? sleeve.host.s : 1
    readonly property real pad: 14 * sleeve.s
    readonly property color line: Theme.border
    readonly property color red: Theme.accent
    readonly property color ink: Theme.cream
    readonly property color dim: Theme.subtle

    /** Spine. */
    Rectangle {
        x: 26 * sleeve.s
        y: sleeve.pad
        width: 1
        height: parent.height - 2 * sleeve.pad
        color: sleeve.line
    }

    Text {
        x: 19 * sleeve.s
        y: sleeve.pad
        width: parent.height - 2 * sleeve.pad
        rotation: 90
        transformOrigin: Item.TopLeft
        text: "TSUGUMORI // " + (sleeve.host ? sleeve.host.serviceLabel : "AUDIO")
        color: sleeve.dim
        elide: Text.ElideRight
        font.family: Theme.fontMono
        font.pixelSize: 8.5 * sleeve.s
        font.letterSpacing: 1
    }

    Item {
        id: content
        anchors.left: parent.left
        anchors.leftMargin: 40 * sleeve.s
        anchors.right: parent.right
        anchors.rightMargin: sleeve.pad
        anchors.top: parent.top
        anchors.topMargin: sleeve.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: sleeve.pad

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12 * sleeve.s

            Text {
                id: archive
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "ARCHIVE"
                color: sleeve.ink
                font.family: Theme.fontMono
                font.pixelSize: 9 * sleeve.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "音楽 // " + (sleeve.host ? sleeve.host.status : "")
                color: sleeve.dim
                font.family: Theme.fontMono
                font.pixelSize: 8 * sleeve.s
            }
        }

        Item {
            id: body
            anchors.top: header.bottom
            anchors.topMargin: 10 * sleeve.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: seek.top
            anchors.bottomMargin: 10 * sleeve.s

            MediaArt {
                id: art
                anchors.verticalCenter: parent.verticalCenter
                width: 64 * sleeve.s
                height: 64 * sleeve.s
                host: sleeve.host
                lineColor: Theme.faint
            }

            Rectangle {
                x: art.width - 22 * sleeve.s
                y: art.y
                width: 22 * sleeve.s
                height: 3 * sleeve.s
                color: sleeve.red
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 11 * sleeve.s
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * sleeve.s

                Text {
                    text: "AUDIO // " + (sleeve.host ? sleeve.host.trackNo : "--")
                    color: sleeve.dim
                    font.family: Theme.fontMono
                    font.pixelSize: 8 * sleeve.s
                }

                Marquee {
                    width: parent.width
                    text: sleeve.host ? sleeve.host.title : ""
                    color: sleeve.ink
                    pixelSize: 17 * sleeve.s
                    weight: Font.DemiBold
                    fontFamily: Theme.fontMono
                    active: sleeve.host ? sleeve.host.active : false
                }

                Marquee {
                    width: parent.width
                    text: sleeve.host ? sleeve.host.sub : ""
                    color: sleeve.dim
                    pixelSize: 9 * sleeve.s
                    fontFamily: Theme.fontMono
                    active: sleeve.host ? sleeve.host.active : false
                    visible: text.length > 0
                }
            }
        }

        MediaSeek {
            id: seek
            anchors.bottom: bottom.top
            anchors.bottomMargin: 10 * sleeve.s
            anchors.left: parent.left
            anchors.right: parent.right
            host: sleeve.host
        }

        Item {
            id: bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 18 * sleeve.s

            MediaTransport {
                id: chips
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                host: sleeve.host
                compact: true
            }

            MediaSources {
                id: sources
                width: 84 * sleeve.s
                anchors.left: chips.right
                anchors.leftMargin: 10 * sleeve.s
                anchors.verticalCenter: parent.verticalCenter
                host: sleeve.host
            }

            MediaStatus {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                host: sleeve.host
                compact: true
            }
        }
    }
}
