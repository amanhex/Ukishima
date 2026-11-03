pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Live status strip for the media designs: wifi throughput, the first connected
 * Bluetooth device with its battery, and the expand action. The expand chip is
 * pinned to the strip's right edge so a churning throughput readout never drags
 * it around; the caller sizes the strip (implicit when right-aligned, full width
 * when it should sit at the end of a bar). `host` is the Media surface;
 * `compact` tightens spacing for header placement.
 */
Item {
    id: status

    property var host: null
    property bool compact: false
    readonly property real s: status.host ? status.host.s : 1
    readonly property real gap: (status.compact ? 10 : 14) * status.s

    implicitWidth: wifiRow.implicitWidth + gap + btRow.implicitWidth + gap + expandItem.width
    implicitHeight: 14 * status.s

    Row {
        id: wifiRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * status.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 11 * status.s
            height: 11 * status.s
            name: "wifi"
            color: Theme.faint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: status.host && status.host.netOk
                ? "↓ " + status.host.fmtNet(status.host.netDown) + "  ↑ " + status.host.fmtNet(status.host.netUp)
                : "OFFLINE"
            color: status.host && status.host.netOk ? Theme.subtle : Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 10 * status.s
            font.features: { "tnum": 1 }
        }
    }

    Row {
        id: btRow
        anchors.left: wifiRow.right
        anchors.leftMargin: status.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * status.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 11 * status.s
            height: 11 * status.s
            name: status.host && status.host.btName.length > 0 ? status.host.btGlyph : "bluetooth"
            color: status.host && status.host.btName.length > 0 ? Theme.subtle : Theme.faint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, (status.compact ? 62 : 88) * status.s)
            text: status.host && status.host.btName.length > 0 ? status.host.btName : "BT"
            color: status.host && status.host.btName.length > 0 ? Theme.subtle : Theme.faint
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: 10 * status.s
        }

        Text {
            visible: status.host && status.host.btBat >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: status.host ? status.host.btBat + "%" : ""
            color: status.host ? status.host.btBatColor : Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 10 * status.s
            font.features: { "tnum": 1 }
        }
    }

    Item {
        id: expandItem
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: expandLabel.implicitWidth + (status.compact ? 0 : 2 * status.s)
        height: 14 * status.s

        Text {
            id: expandLabel
            anchors.centerIn: parent
            text: "EXPAND"
            color: expandArea.containsMouse ? Theme.vermLit : Theme.dim
            font.family: Theme.fontMono
            font.pixelSize: 10 * status.s
            font.letterSpacing: 0.5
        }

        MouseArea {
            id: expandArea
            anchors.fill: parent
            anchors.margins: -3 * status.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (status.host) status.host.requestExpand()
        }
    }
}
