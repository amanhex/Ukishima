pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Ledger": two ruled columns. The left is the record — cover, album
 * and artist stamped under "NOW SELECTED"; the right is the deck — track
 * title, the source picker, transport, seek, and the live status line. `host`
 * is Media.
 */
Item {
    id: ledger

    property var host: null
    readonly property real s: ledger.host ? ledger.host.s : 1
    readonly property real pad: 14 * ledger.s
    readonly property real leftW: 176 * ledger.s
    readonly property color line: Theme.border
    readonly property color red: Theme.accent
    readonly property color ink: Theme.cream
    readonly property color dim: Theme.subtle

    Rectangle {
        id: divider
        x: ledger.pad + ledger.leftW
        y: ledger.pad
        width: 1
        height: parent.height - 2 * ledger.pad
        color: ledger.line
    }

    /** Left column: cover with its ledger notes beside it, stamped at the foot. */
    Item {
        anchors.left: parent.left
        anchors.leftMargin: ledger.pad
        anchors.top: parent.top
        anchors.topMargin: ledger.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ledger.pad
        width: ledger.leftW

        Item {
            id: record
            anchors.top: parent.top
            anchors.bottom: footRule.top
            anchors.left: parent.left
            anchors.right: parent.right

            MediaArt {
                id: art
                anchors.verticalCenter: parent.verticalCenter
                width: 84 * ledger.s
                height: 84 * ledger.s
                host: ledger.host
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 9 * ledger.s
                anchors.right: parent.right
                anchors.rightMargin: 4 * ledger.s
                anchors.verticalCenter: art.verticalCenter
                spacing: 3 * ledger.s

                Text {
                    text: "NOW SELECTED"
                    color: Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 7.5 * ledger.s
                    font.letterSpacing: 0.5
                }

                Text {
                    width: parent.width
                    text: ledger.host ? (ledger.host.album.length > 0 ? ledger.host.album : ledger.host.title) : ""
                    color: ledger.ink
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: 10 * ledger.s
                }

                Text {
                    width: parent.width
                    text: ledger.host ? ledger.host.artist : ""
                    color: ledger.dim
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: 9 * ledger.s
                }
            }
        }

        Rectangle {
            id: footRule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: foot.top
            anchors.bottomMargin: 5 * ledger.s
            height: 1
            color: ledger.line
        }

        Item {
            id: foot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 10 * ledger.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "音楽 // " + (ledger.host ? ledger.host.serviceLabel : "")
                color: ledger.red
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: 8 * ledger.s
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "TRK " + (ledger.host ? ledger.host.trackNo : "--")
                color: Theme.faint
                font.family: Theme.fontMono
                font.pixelSize: 7.5 * ledger.s
            }
        }
    }

    /** Right column: deck. */
    Column {
        anchors.left: divider.right
        anchors.leftMargin: 10 * ledger.s
        anchors.right: parent.right
        anchors.rightMargin: ledger.pad
        anchors.top: parent.top
        anchors.topMargin: ledger.pad
        spacing: 16 * ledger.s

        Marquee {
            width: parent.width
            text: ledger.host ? ledger.host.title : ""
            color: ledger.ink
            pixelSize: 13 * ledger.s
            weight: Font.DemiBold
            fontFamily: Theme.fontMono
            active: ledger.host ? ledger.host.active : false
        }

        MediaSources {
            width: parent.width
            host: ledger.host
        }

        MediaTransport {
            host: ledger.host
            compact: true
        }

        MediaSeek {
            width: parent.width
            host: ledger.host
        }

        MediaStatus {
            width: parent.width
            host: ledger.host
            compact: true
        }
    }
}
