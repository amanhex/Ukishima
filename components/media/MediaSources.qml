pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import ".."
import "../../Singletons"

/**
 * Source chip + player picker used by the Chaldea-style media designs.
 *
 * Idle it shows "SOURCE // <service>"; with more than one player running it
 * becomes the glowing chip that opens a horizontal picker. `host` is the Media
 * surface, which owns `picking` and the player list comes from Players.
 */
Item {
    id: src

    property var host: null
    readonly property real s: src.host ? src.host.s : 1
    readonly property bool picking: src.host ? src.host.picking : false
    readonly property bool canPick: src.host ? src.host.canPick : false

    implicitHeight: 16 * src.s
    clip: false

    /** Idle row: plain source label, or the chip when several players run. */
    Item {
        anchors.fill: parent
        opacity: src.picking ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Text {
            id: plain
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !src.canPick
            text: "SOURCE // " + (src.host ? src.host.serviceLabel : "")
            color: Theme.dim
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * src.s
        }

        Rectangle {
            id: chip
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: src.canPick
            height: 15 * src.s
            width: Math.min(parent.width, chipRow.implicitWidth + 14 * src.s)
            color: chipHover.hovered ? Theme.cardTop : Theme.cardBot
            border.width: 1
            border.color: Theme.accent

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 4 * src.s
                clip: true

                ArtDot {
                    anchors.verticalCenter: parent.verticalCenter
                    url: Players.artUrlFor(src.host ? src.host.player : null)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 54 * src.s)
                    text: src.host ? src.host.serviceLabel : ""
                    color: Theme.cream
                    elide: Text.ElideRight
                    font.family: Theme.fontMono
                    font.pixelSize: 8.5 * src.s
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▾"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 8 * src.s
                }
            }

            HoverHandler { id: chipHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (src.host) src.host.picking = true
            }
        }
    }

    /** Open picker: the running players, scrolled horizontally. */
    Flickable {
        id: pickFlick
        anchors.fill: parent
        clip: true
        opacity: src.picking ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        contentWidth: pickRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                var step = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x;
                var max = Math.max(0, pickFlick.contentWidth - pickFlick.width);
                pickFlick.contentX = Math.max(0, Math.min(max, pickFlick.contentX - step));
            }
        }

        Row {
            id: pickRow
            height: pickFlick.height
            spacing: 5 * src.s

            Repeater {
                model: src.picking ? Players.pickable : []
                delegate: Rectangle {
                    id: bub
                    required property var modelData
                    readonly property bool isActive: modelData === Players.active
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18 * src.s
                    width: bubInner.implicitWidth + 12 * src.s
                    color: bub.isActive ? Qt.alpha(Theme.accent, 0.10) : Theme.cardBot
                    border.width: 1
                    border.color: bub.isActive ? Theme.accent : Qt.alpha(Theme.cream, 0.22)

                    Row {
                        id: bubInner
                        anchors.centerIn: parent
                        spacing: 4 * src.s

                        ArtDot {
                            anchors.verticalCenter: parent.verticalCenter
                            url: Players.artUrlFor(bub.modelData)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Players.labelOf(bub.modelData)
                            color: bub.isActive ? Theme.cream : Theme.subtle
                            font.family: Theme.fontMono
                            font.pixelSize: 8.5 * src.s
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Players.select(bub.modelData);
                            if (src.host)
                                src.host.picking = false;
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * src.s
                height: 16 * src.s
                color: closeArea.containsMouse ? Theme.cardTop : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.cream, 0.22)

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Theme.subtle
                    font.family: Theme.fontMono
                    font.pixelSize: 9 * src.s
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (src.host) src.host.picking = false
                }
            }
        }
    }

    Connections {
        target: src.host
        function onPickingChanged() {
            if (src.picking)
                pickFlick.contentX = 0;
        }
    }

    component ArtDot: ClippingRectangle {
        id: dot
        property string url: ""
        width: 9 * src.s
        height: 9 * src.s
        radius: width / 2
        color: Theme.tileBg

        Image {
            anchors.fill: parent
            source: dot.url
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
    }
}
