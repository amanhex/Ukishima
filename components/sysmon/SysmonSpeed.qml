pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Compact Chaldea-style speed-test strip: down / ping / up and the trigger,
 * reading the owning SysmonSurface's process state. `host` is SysmonSurface.
 */
Item {
    id: speed

    property var host: null
    readonly property real s: speed.host ? speed.host.s : 1
    readonly property bool running: speed.host ? speed.host.speedRunning : false
    readonly property string phase: speed.host ? speed.host.speedPhase : ""
    readonly property string err: speed.host ? speed.host.speedError : ""

    implicitHeight: (speed.err.length > 0 ? 34 : 22) * speed.s

    Row {
        id: stats
        anchors.left: parent.left
        anchors.top: parent.top
        height: 22 * speed.s
        spacing: 14 * speed.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "↓ " + (speed.host && speed.host.speedDown > 0 ? speed.host.fmtSpeed(speed.host.speedDown) : "---")
            color: speed.phase === "download" ? Theme.vermLit : Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * speed.s
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "↑ " + (speed.host && speed.host.speedUp > 0 ? speed.host.fmtSpeed(speed.host.speedUp) : "---")
            color: speed.phase === "upload" ? Theme.vermLit : Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * speed.s
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "PING " + (speed.host && speed.host.speedPing > 0 ? speed.host.speedPing + "ms" : "---")
            color: speed.phase === "ping" ? Theme.vermLit : Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * speed.s
            font.features: { "tnum": 1 }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        width: 52 * speed.s
        height: 22 * speed.s
        color: speed.running ? Qt.alpha(Theme.vermLit, 0.15)
            : (speed.err.length > 0 ? Qt.alpha(Theme.verm, 0.15) : Qt.alpha(Theme.cream, 0.06))
        border.width: 1
        border.color: speed.running ? Theme.vermLit
            : (speed.err.length > 0 ? Theme.verm : Theme.border)

        Text {
            anchors.centerIn: parent
            text: speed.running ? "..." : "TEST"
            color: speed.running ? Theme.vermLit : Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 8 * speed.s
            font.letterSpacing: 0.8
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!speed.host)
                    return;
                if (speed.running)
                    speed.host.stopSpeed();
                else
                    speed.host.startSpeed();
            }
        }
    }

    Text {
        visible: speed.err.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 24 * speed.s
        text: "⚠  " + speed.err
        color: Theme.vermLit
        elide: Text.ElideRight
        font.family: Theme.fontMono
        font.pixelSize: 8 * speed.s
    }
}
