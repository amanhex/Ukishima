pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"

/**
 * Per-app playback list for the sound surface: every sink stream with a mute
 * toggle, a volume fader and an output chip that re-routes it. The host (the
 * sound surface) supplies `s` and `live`; the routing menu floats above the list.
 */
Item {
    id: root

    property real s: 1
    /** True while this panel is the mixer's visible view; pops the routing menu on hide. */
    property bool live: false

    property var routeStream: null
    property real routeY: 0

    implicitHeight: Sound.apps.length ? appsList.height : 56 * root.s

    onLiveChanged: if (!live)
        root.routeStream = null;

    /** App label from the stream: the binary when the client only reports a generic engine name (Chromium, WebRTC). */
    function appName(node, p) {
        const bin = p["application.process.binary"] || "";
        const name = p["application.name"] || "";
        if (bin && !/wine|preloader|python|java|\.exe$/i.test(bin) && (!name || /chrom|webrtc|electron|playback|alsa/i.test(name)))
            return bin.charAt(0).toUpperCase() + bin.slice(1);
        return name || node.description || node.name || "App";
    }

    component AppRow: Item {
        id: app
        required property var modelData
        readonly property var props: modelData.properties || {}
        readonly property var target: Sound.targetOf(modelData)
        readonly property real vol: modelData.audio ? modelData.audio.volume : 0
        readonly property bool muted: modelData.audio ? modelData.audio.muted : false

        width: appsList.width
        height: 42 * root.s

        HoverHandler { id: appHover }

        Column {
            id: appText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 108 * root.s
            spacing: 2 * root.s
            Text {
                width: parent.width
                text: root.appName(app.modelData, app.props)
                elide: Text.ElideRight
                color: appHover.hovered ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: app.props["media.name"] || ""
                elide: Text.ElideRight
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
            }
        }

        Item {
            id: muteBtn
            anchors.left: appText.right
            anchors.leftMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s

            GlyphIcon {
                anchors.fill: parent
                name: app.muted ? "speaker-off" : "speaker"
                color: app.muted ? Theme.dim : (muteArea.containsMouse ? Theme.cream : Theme.iconDim)
                stroke: 1.7
            }

            MouseArea {
                id: muteArea
                anchors.fill: parent
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.setNodeMuted(app.modelData, !app.muted)
            }
        }

        HFader {
            anchors.left: muteBtn.right
            anchors.leftMargin: 12 * root.s
            anchors.right: devChip.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            value: app.vol / 2
            readout: Math.round(app.vol * 100) + "%"
            focused: appHover.hovered
            on: !app.muted
            onMoved: (v) => Sound.setNodeVolume(app.modelData, Math.round(v * 200) / 100, "app" + app.modelData.id, "App volume")
        }

        Rectangle {
            id: devChip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 90 * root.s
            height: 22 * root.s
            radius: 7 * root.s
            color: root.routeStream === app.modelData ? Qt.alpha(Theme.onGlow, 0.14) : (chipArea.containsMouse ? Theme.frameBg : "transparent")
            border.width: 1
            border.color: root.routeStream === app.modelData ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border

            Text {
                anchors.fill: parent
                anchors.leftMargin: 8 * root.s
                anchors.rightMargin: 8 * root.s
                verticalAlignment: Text.AlignVCenter
                text: app.target ? (app.target.nickname || routeMenu.label(app.target)) : "Default"
                elide: Text.ElideRight
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.routeY = app.mapToItem(root, 0, app.height).y;
                    root.routeStream = root.routeStream === app.modelData ? null : app.modelData;
                }
            }
        }
    }

    Text {
        visible: !Sound.apps.length
        anchors.centerIn: parent
        text: "Nothing is playing"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
    }

    ListView {
        id: appsList
        width: parent.width
        height: Math.min(count, 6) * 42 * root.s
        interactive: count > 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Sound.apps
        delegate: AppRow {}
    }

    DeviceMenu {
        id: routeMenu
        s: root.s
        open: root.routeStream !== null
        anchors.top: parent.top
        anchors.topMargin: root.routeY + 2 * root.s
        anchors.right: parent.right
        width: 240 * root.s
        model: Sound.outputSinks
        current: root.routeStream ? Sound.targetOf(root.routeStream) : null
        onPick: (node) => {
            Sound.route(root.routeStream, node);
            root.routeStream = null;
        }
    }
}
