import QtQuick
import QtQuick.Effects

/**
 * Visual password field for the lock designs. Input itself stays on
 * LockSurface's raw key handler (the only path that survives a WlSessionLock
 * without dropping characters); this only paints the dots, the prompt, the
 * error state and the enter button.
 */
Item {
    id: root

    property var host: null
    property color ink: "#e4e2dc"
    property color muted: "#98948a"
    property color accent: "#d1161c"
    property color line: "#393630"
    property color ground: "#090909"
    readonly property bool isSharpCapture: root.host ? (root.host.background === "capture" && root.host.blurMax <= 16) : false
    readonly property real effectiveGroundOpacity: isSharpCapture ? 0.90 : root.groundOpacity
    //* Opacity of the dark plate under the prompt/dots. The line-only style
    //* draws no fill at all, so over a sharp capture or a busy wallpaper the
    //* 11-12px mono text and dots sat directly on whatever was behind them.
    property real groundOpacity: 0.55
    property bool boxed: false
    property bool showEnter: true
    property real pad: 12
    property real radius: 0

    readonly property var ctx: root.host ? root.host.context : null
    readonly property int len: root.ctx ? root.ctx.currentText.length : 0
    readonly property bool busy: root.ctx ? root.ctx.unlockInProgress : false
    readonly property bool failed: root.ctx ? root.ctx.showFailure : false

    implicitHeight: 44
    implicitWidth: 300

    //* Readable plate under the prompt, dots and enter button. Kept for both
    //* styles: the boxed variant only tinted white at 0.04 over whatever was
    //* behind it, which is not a background on a sharp capture.
    Rectangle {
        anchors.fill: parent
        radius: Math.max(root.radius, 4)
        color: root.isSharpCapture ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(root.ground.r, root.ground.g, root.ground.b, root.groundOpacity)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: root.isSharpCapture
            blur: 1
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.boxed
        radius: root.radius
        color: Qt.rgba(1, 1, 1, 0.04)
        border.color: root.failed ? root.accent : root.line
        border.width: 1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.boxed
        height: 1
        color: root.failed ? root.accent : root.line
    }

    Item {
        id: mid

        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.right: enter.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.len === 0 && !root.busy
            text: root.failed ? "Incorrect password" : "Enter password"
            color: root.failed ? root.accent : root.muted
            font.family: "JetBrainsMono NF"
            font.pixelSize: 12
            font.letterSpacing: 0.8
            elide: Text.ElideRight
        }

        Row {
            anchors.centerIn: parent
            spacing: 7
            visible: root.len > 0 && !root.busy

            Repeater {
                model: root.len

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: root.ink
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.busy
            text: "AUTHENTICATING"
            color: root.muted
            font.family: "JetBrainsMono NF"
            font.pixelSize: 11
            font.letterSpacing: 1.4
        }
    }

    Item {
        id: enter

        visible: root.showEnter && !root.busy
        anchors.right: parent.right
        anchors.rightMargin: root.boxed ? root.pad : 0
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.len > 0 ? root.accent : "transparent"
            border.color: root.len > 0 ? root.accent : root.line
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "\u2192"
                color: root.len > 0 ? root.ground : root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 13
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.len > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.len > 0)
                root.ctx.tryUnlock()
        }
    }

    transform: Translate {
        id: shake
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation { target: shake; property: "x"; to: -8; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: shake; property: "x"; to: 7; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: -4; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
    }

    Connections {
        target: root.ctx

        function onShowFailureChanged() {
            if (root.ctx && root.ctx.showFailure)
                shakeAnim.start();
        }
    }
}