import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

/**
 * Avatar + user name for the lock designs. Mirrors the default lock's avatar
 * cascade: the configured image when it loads, otherwise a person glyph.
 */
Item {
    id: root

    property var host: null
    property real avatarSize: 64
    //* `horizontal` puts the avatar beside the name instead of above it, for
    //* the wide lock designs where the login column is a single row. The
    //* default lock keeps the stacked arrangement.
    property bool horizontal: false
    property real gap: 12
    property bool showAvatar: true
    property color ink: "#e4e2dc"
    property color muted: "#98948a"
    readonly property bool isSharpCapture: root.host ? (root.host.background === "capture" && root.host.blurMax <= 16) : false

    readonly property bool avatarVisible: root.showAvatar && root.host && root.host.showAvatar

    implicitWidth: root.horizontal
        ? (root.avatarVisible ? root.avatarSize + root.gap : 0) + name.implicitWidth
        : Math.max(root.avatarVisible ? root.avatarSize : 0, name.implicitWidth)
    implicitHeight: root.horizontal
        ? Math.max(root.avatarVisible ? root.avatarSize : 0, name.implicitHeight)
        : (root.avatarVisible ? root.avatarSize + 8 : 0) + name.implicitHeight

    Item {
        id: avatarBox

        visible: root.avatarVisible
        width: root.avatarSize
        height: root.avatarSize
        x: root.horizontal ? 0 : (root.width - width) / 2
        y: root.horizontal ? (root.height - height) / 2 : 0

        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#232323"

            Image {
                id: face

                anchors.fill: parent
                source: root.host && root.host.avatarWanted ? "file://" + root.host.facePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !face.visible
                text: "\uf007"
                color: root.muted
                font.family: "JetBrainsMono NFM"
                font.pixelSize: root.avatarSize * 0.3
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.28)
        }
    }

    //* Readable plate behind the user name: the avatar already draws its own
    //* dark disc, but the name was bare 10px mono over the backdrop.
    Rectangle {
        readonly property real padX: 7
        readonly property real padY: 3

        x: name.x + (root.horizontal ? 0 : (name.width - name.implicitWidth) / 2) - padX
        y: name.y + (name.height - name.implicitHeight) / 2 - padY
        width: name.implicitWidth + padX * 2
        height: name.implicitHeight + padY * 2
        radius: 3
        color: root.isSharpCapture ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(0, 0, 0, 0.5)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: root.isSharpCapture
            blur: 1
        }
    }

    Text {
        id: name

        x: root.horizontal ? (root.avatarVisible ? root.avatarSize + root.gap : 0) : 0
        y: root.horizontal
            ? (root.height - implicitHeight) / 2
            : (root.avatarVisible ? root.avatarSize + 8 : 0)
        width: root.width - x
        text: root.host ? root.host.userName : ""
        color: root.ink
        font.family: "JetBrainsMono NF"
        font.pixelSize: Math.max(10, root.avatarSize * 0.16)
        font.letterSpacing: 1
        horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
        elide: Text.ElideRight
    }
}