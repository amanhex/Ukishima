pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Widgets
import "../Singletons"
import "../components"

/**
 * Now-playing card. A small square cover floats detached on the left; the
 * middle stacks the source line, title, artist·album and the seek seam with
 * the transport controls; the right end carries three minimal live reads —
 * network speed, the first connected Bluetooth device with battery, and the
 * toggle that keeps the pill expanded. Nothing bleeds off the card and no
 * cover wash tints it, so the background stays the theme gradient. The seam's
 * brush head docks the pill's soul bead (Ame). Now-playing data comes from
 * [[Players]]; with several players running the source token glows into a
 * bubble that opens a picker.
 */
PillSurface {
    id: root

    /** Squared top corners when the pill is in strip mode; 0 = rounded everywhere. */
    property real topFlat: 0
    Behavior on topFlat { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    /** Pin state: the right-end toggle keeps the expanded pill open after the card closes. */
    property bool pinned: false
    signal requestPin()
    signal requestExpand()

    /**
     * With expandTo "media" the card is hover-driven in every auto-hide mode:
     * leaving it (past a small margin + grace window) closes the surface again
     * so the pill shrinks back to rest (or hides). Pinning disarms the guard.
     */
    Timer {
        id: leaveGuardT
        interval: 120
        onTriggered: root.requestClose()
    }

    HoverHandler {
        id: leaveGuard
        enabled: root.open && Flags.expandTo === "media" && !root.pinned
        margin: 10 * root.s
        onHoveredChanged: {
            if (enabled && !hovered)
                leaveGuardT.start();
            else if (enabled)
                leaveGuardT.stop();
        }
    }

    readonly property var player: Players.active
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: Players.playing
    readonly property string title: Players.has && Players.title ? Players.title : "Nothing playing"
    readonly property string artist: Players.artist
    readonly property string album: Players.album
    readonly property bool live: Players.live
    readonly property string serviceLabel: Players.serviceLabel

    /** artist · album, whichever of the two exists */
    readonly property string sub: {
        var parts = [];
        if (root.artist.length > 0) parts.push(root.artist);
        if (root.album.length > 0) parts.push(root.album);
        return parts.join(" · ");
    }

    /** Loop toggle. MprisLoopState walks None -> Track -> Playlist -> None. */
    readonly property bool loopOk: hasPlayer && root.player.loopSupported && root.player.canControl
    readonly property bool loopNone: !hasPlayer || !root.loopOk || root.player.loopState === MprisLoopState.None
    readonly property bool loopTrack: hasPlayer && root.loopOk && root.player.loopState === MprisLoopState.Track
    readonly property bool loopPlaylist: hasPlayer && root.loopOk && root.player.loopState === MprisLoopState.Playlist
    function nextLoop() {
        if (!root.player)
            return;
        if (root.player.loopState === MprisLoopState.None)
            root.player.loopState = MprisLoopState.Track;
        else if (root.player.loopState === MprisLoopState.Track)
            root.player.loopState = MprisLoopState.Playlist;
        else
            root.player.loopState = MprisLoopState.None;
    }

    /** Live throughput (MB/s) read straight from /proc/net/dev while the card is open. */
    property real netDown: 0
    property real netUp: 0
    property bool netOk: false
    property real netPrevRx: 0
    property real netPrevTx: 0
    property real netPrevTime: 0
    function fmtNet(v) {
        if (!(v > 0))
            return "0";
        if (v >= 1)
            return v.toFixed(1) + "M";
        var kb = v * 1024;
        return (kb >= 10 ? Math.round(kb) : kb.toFixed(1)) + "K";
    }

    /** First connected Bluetooth device plus its battery, when BlueZ reports one. */
    readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property var btConnected: {
        var out = [];
        for (var i = 0; i < root.btDevices.length; i++)
            if (root.btDevices[i] && root.btDevices[i].connected) out.push(root.btDevices[i]);
        return out;
    }
    function batteryOf(d) {
        if (!d || d.battery === undefined || d.battery === null || d.battery <= 0)
            return -1;
        var b = d.battery;
        if (b <= 1)
            b = b * 100;
        return Math.round(b);
    }
    readonly property var btPick: {
        var first = null;
        for (var i = 0; i < root.btConnected.length; i++) {
            var d = root.btConnected[i];
            if (!first)
                first = d;
            if (root.batteryOf(d) >= 0)
                return d;
        }
        return first;
    }
    readonly property string btName: btPick ? (btPick.deviceName || btPick.name || "Bluetooth device") : ""
    readonly property int btBat: btPick ? root.batteryOf(btPick) : -1
    readonly property color btBatColor: root.btBat >= 50 ? Theme.cream : root.btBat >= 20 ? Theme.dim : Theme.vermDeep
    readonly property string btGlyph: {
        var icon = btPick ? (btPick.icon || "") : "";
        var n = btName.toLowerCase();
        switch (icon) {
        case "audio-headset":
        case "audio-headphones":
        case "audio-headset-mic":
            return "headphones";
        case "audio-card":
            return "speaker";
        case "audio-input-mic":
            return "mic";
        case "phone":
            return "phone";
        case "watch":
            return "watch";
        case "computer":
        case "laptop":
            return "computer";
        case "input-keyboard":
            return "keyboard";
        case "input-mouse":
        case "input-tablet":
            return "mouse";
        case "input-gaming":
            return "gamepad";
        case "tv":
            return "tv";
        case "printer":
        case "scanner":
        case "multifunction-printer":
            return "printer";
        case "camera-video":
        case "camera-photo":
            return "camera";
        }
        if (n.indexOf("earbud") >= 0 || n.indexOf("buds") >= 0 || n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0)
            return "headphones";
        if (n.indexOf("phone") >= 0 || n.indexOf("mobile") >= 0)
            return "phone";
        if (n.indexOf("watch") >= 0)
            return "watch";
        if (n.indexOf("keyboard") >= 0)
            return "keyboard";
        if (n.indexOf("mouse") >= 0)
            return "mouse";
        if (n.indexOf("speaker") >= 0)
            return "speaker";
        return "bluetooth";
    }

    /**
     * Art only decodes while this monitor's surface is open, keyed on the track
     * so a browser reusing one file path still reloads on a new song. The shared
     * url means every monitor shows the same cover, never a stale neighbour.
     */
    readonly property string coverSource: {
        if (!root.active)
            return "";
        var u = Players.artUrl;
        if (u)
            return u.indexOf("file:") === 0 ? u + "#" + Players.trackKey : u;
        return Players.appIconFor(root.player);
    }
    /** Latched on first decode so the fallback glyph doesn't flash back while a track change reloads behind the retained cover. */
    property bool everReady: false
    onCoverSourceChanged: if (coverSource.length === 0) everReady = false

    readonly property real lengthSec: Players.lengthSec
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real playFrac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0
    property real dragFrac: 0
    property bool dragging: false
    readonly property real frac: dragging ? dragFrac : playFrac

    /** Source picker is open; only reachable when more than one player runs. */
    property bool picking: false
    readonly property bool canPick: Players.pickable.length > 1
    onCanPickChanged: if (!canPick) picking = false
    onPickingChanged: if (picking) pickFlick.contentX = 0

    /** Card geometry tokens, all scaled to the monitor. */
    readonly property real pad: 12 * s
    readonly property real artSize: 88 * s
    readonly property real artMargin: 16 * s
    readonly property real gapArt: 10 * s
    readonly property real textX: root.artMargin + root.artSize + root.gapArt
    readonly property real textColW: 190 * s
    readonly property real railW: 96 * s
    readonly property real railInset: 24 * s

    property real sealPulse: 0

    readonly property point seamHead: {
        void root.width;
        void root.height;
        void root.frac;
        void stroke.x;
        void stroke.width;
        return stroke.mapToItem(root, stroke.headX, stroke.headY);
    }
    readonly property real seamHeadX: seamHead.x
    readonly property real seamHeadY: seamHead.y

    ameForm: "seam"
    amePoint: Qt.point(seamHeadX, seamHeadY)

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    onTitleChanged: if (playing && active) pulseAnim.restart()

    Timer {
        interval: 500
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    Process {
        id: netProc
        command: ["sh", "-c", "awk 'NR>2{gsub(\":\",\" \");if($1!=\"lo\"){rx+=$2;tx+=$10}}END{print \"NET\",rx+0,tx+0}' /proc/net/dev; for i in /sys/class/net/wl*/; do [ -d \"$i\" ] && [ \"$(cat \"$i/operstate\")\" = up ] && { echo WIFI up; exit 0; }; done; echo WIFI down"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split(/\s+/);
                if (p.length < 3 || p[0] !== "NET")
                    return;
                var rx = parseFloat(p[1]);
                var tx = parseFloat(p[2]);
                var now = Date.now();
                var dt = (now - root.netPrevTime) / 1000;
                if (root.netPrevTime > 0 && dt > 0) {
                    root.netDown = Math.max(0, (rx - root.netPrevRx) / dt / 1048576);
                    root.netUp = Math.max(0, (tx - root.netPrevTx) / dt / 1048576);
                }
                root.netPrevRx = rx;
                root.netPrevTx = tx;
                root.netPrevTime = now;
                root.netOk = p.indexOf("WIFI") >= 0 && p[p.indexOf("WIFI") + 1] === "up";
            }
        }
    }

    Timer {
        interval: 500
        running: root.active
        repeat: true
        onTriggered: if (!netProc.running) netProc.running = true
    }
    onActiveChanged: {
        if (!active)
            picking = false;
        else if (!netProc.running)
            netProc.running = true;
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "sealPulse"; to: 1; duration: Motion.fast; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "sealPulse"; to: 0; duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    component KanjiSkip: Item {
        id: skip

        property bool can: false
        property string kanjiText: ""
        property string icon: ""
        signal activated()

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Flags.showGlyphs ? kanjiLabel.implicitWidth : 15 * root.s
        implicitHeight: Flags.showGlyphs ? kanjiLabel.implicitHeight : 15 * root.s
        opacity: skip.can ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        Text {
            id: kanjiLabel
            visible: Flags.showGlyphs
            anchors.centerIn: parent
            text: skip.kanjiText
            font.family: Theme.fontJp
            font.pixelSize: 11 * root.s
            color: skipArea.containsMouse ? Theme.cream : Theme.dim
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        GlyphIcon {
            visible: !Flags.showGlyphs
            anchors.centerIn: parent
            width: 14 * root.s
            height: 14 * root.s
            name: skip.icon
            color: skipArea.containsMouse ? Theme.cream : Theme.dim
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            id: skipArea
            anchors.fill: parent
            anchors.margins: -7 * root.s
            hoverEnabled: true
            enabled: skip.can
            cursorShape: Qt.PointingHandCursor
            onClicked: skip.activated()
        }
    }

    component ArtDot: ClippingRectangle {
        id: dot
        property string url: ""
        width: 10 * root.s
        height: 10 * root.s
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

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 20 * root.s
        topLeftRadius: radius * (1 - root.topFlat)
        topRightRadius: radius * (1 - root.topFlat)
        border.width: 1
        border.color: Theme.frameBorder

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
    }

    /** Square cover floating detached from every edge. */
    Item {
        id: art
        anchors.left: parent.left
        anchors.leftMargin: root.artMargin
        anchors.verticalCenter: parent.verticalCenter
        width: root.artSize
        height: root.artSize

        ClippingRectangle {
            anchors.fill: parent
            radius: 18 * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.frameBorder

            Rectangle {
                anchors.fill: parent
                color: Theme.tileBg
                visible: !root.everReady
            }

            Image {
                id: cover
                anchors.fill: parent
                source: root.coverSource
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                retainWhileLoading: true
                cache: String(source).indexOf("file:") !== 0
                onStatusChanged: {
                    if (status === Image.Ready)
                        root.everReady = true;
                    else if (status === Image.Error && cover.source !== "")
                        root.everReady = false;
                }
            }
        }

        /** No art yet: a small equalizer while playing, a note glyph otherwise. */
        Item {
            anchors.fill: parent
            visible: !root.everReady

            Row {
                id: eq
                anchors.centerIn: parent
                spacing: 3 * root.s
                visible: root.playing

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 3 * root.s
                        height: 7 * root.s
                        radius: width / 2
                        color: Theme.vermLit

                        SequentialAnimation on height {
                            running: eq.visible && root.playing
                            loops: Animation.Infinite
                            NumberAnimation { to: (6 + index * 3) * root.s; duration: 360 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: (12 - index * 2) * root.s; duration: 400 + index * 90; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            GlyphIcon {
                anchors.centerIn: parent
                width: 24 * root.s
                height: 24 * root.s
                name: "music"
                color: Theme.subtle
                visible: !root.playing
            }
        }
    }

    /** Right-end rail: wifi speed, connected bluetooth device with power, pin toggle. */
    Item {
        id: infoStack
        anchors.right: parent.right
        anchors.rightMargin: root.railInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.railW
        height: infoCol.height

        Column {
            id: infoCol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 14 * root.s

            Row {
                width: infoStack.width
                height: 15 * root.s
                spacing: 6 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s
                    height: 12 * root.s
                    name: "wifi"
                    color: Theme.iconDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 18 * root.s)
                    text: root.netOk
                        ? "↓ " + root.fmtNet(root.netDown) + "  ↑ " + root.fmtNet(root.netUp)
                        : "Not connected"
                    elide: Text.ElideRight
                    color: root.netOk ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.features: { "tnum": 1 }
                }
            }

            Row {
                width: infoStack.width
                height: 15 * root.s
                spacing: 5 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s
                    height: 12 * root.s
                    name: root.btGlyph
                    color: Theme.iconDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 12 * root.s - 5 * root.s - (root.btBat >= 0 ? 22 * root.s : 0) - 5 * root.s)
                    text: root.btName.length > 0 ? root.btName : "Not connected"
                    elide: Text.ElideRight
                    color: root.btName.length > 0 ? Theme.dim : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.features: { "tnum": 1 }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.btBat >= 0
                    width: 22 * root.s
                    text: root.btBat >= 0 ? root.btBat + "%" : ""
                    horizontalAlignment: Text.AlignRight
                    color: root.btBatColor
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            Item {
                width: infoStack.width
                height: 15 * root.s

                Row {
                    width: infoStack.width
                    spacing: 6 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s
                        height: 12 * root.s
                        name: "layers"
                        color: Theme.iconDim
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Expand"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestExpand()
                }
            }
        }
    }

    Column {
        id: textCol
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.textX
        width: root.textColW
        spacing: 3 * root.s

        /** Source line: plain service, or the glowing picker bubble when several players run. */
        Item {
            id: srcHeader
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.picking ? 22 * root.s : 12 * root.s

            readonly property string tail: root.live
                ? " - Live"
                : " / " + root.fmt(root.dragging ? root.dragFrac * root.lengthSec : root.positionSec)
                    + " - " + root.fmt(root.lengthSec)

            Item {
                id: infoRow
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: root.picking ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                Text {
                    id: plainSource
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.canPick && root.serviceLabel.length > 0
                    text: root.serviceLabel
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                }

                Rectangle {
                    id: srcBubble
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.canPick
                    height: 14 * root.s
                    width: bubbleRow.width + 12 * root.s
                    radius: height / 2
                    color: Qt.alpha(Theme.verm, 0.16)
                    border.width: 1
                    border.color: Qt.alpha(Theme.vermLit, 0.45 + 0.35 * glow)

                    property real glow: 0
                    SequentialAnimation on glow {
                        running: srcBubble.visible && !root.picking
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 1300; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 1300; easing.type: Easing.InOutSine }
                    }

                    Row {
                        id: bubbleRow
                        anchors.centerIn: parent
                        spacing: 4 * root.s
                        ArtDot {
                            anchors.verticalCenter: parent.verticalCenter
                            url: Players.artUrlFor(root.player)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.serviceLabel
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "▾"
                            color: Theme.vermLit
                            font.pixelSize: 7 * root.s
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picking = true
                    }
                }

                Text {
                    anchors.left: root.canPick ? srcBubble.right : plainSource.right
                    anchors.leftMargin: 3 * root.s
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: srcHeader.tail
                    elide: Text.ElideRight
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.features: { "tnum": 1 }
                }
            }

            Flickable {
                id: pickFlick
                anchors.fill: parent
                clip: true
                visible: opacity > 0.01
                opacity: root.picking ? 1 : 0
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
                    spacing: 7 * root.s

                    Repeater {
                        model: root.picking ? Players.pickable : []
                        delegate: Rectangle {
                            id: bub
                            required property var modelData
                            readonly property bool isActive: modelData === Players.active
                            anchors.verticalCenter: parent.verticalCenter
                            height: 20 * root.s
                            width: bubInner.width + 14 * root.s
                            radius: 8 * root.s
                            color: isActive ? Qt.alpha(Theme.verm, 0.2) : Qt.alpha(Theme.cream, 0.045)
                            border.width: 1
                            border.color: isActive ? Theme.vermLit : Qt.alpha(Theme.cream, 0.12)

                            Row {
                                id: bubInner
                                anchors.centerIn: parent
                                spacing: 5 * root.s
                                ArtDot {
                                    anchors.verticalCenter: parent.verticalCenter
                                    url: Players.artUrlFor(bub.modelData)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Players.labelOf(bub.modelData)
                                    color: bub.isActive ? Theme.bright : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 9 * root.s
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Players.select(bub.modelData);
                                    root.picking = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        Marquee {
            id: titleLbl
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.title
            color: Theme.cream
            pixelSize: 12.5 * root.s
            weight: Font.DemiBold
            active: root.active
        }

        Marquee {
            id: subLbl
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.sub
            color: Theme.dim
            pixelSize: 9.5 * root.s
            active: root.active
            visible: text.length > 0
        }

        /** Seek row: position, the wave seam, duration, loop toggle. */
        Item {
            id: seekRow
            anchors.left: parent.left
            anchors.right: parent.right
            height: 12 * root.s

            Text {
                id: posLbl
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmt(root.dragging ? root.dragFrac * root.lengthSec : root.positionSec)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.features: { "tnum": 1 }
            }

            /** Loop chip: Off / Track (single-repeat / Playlist. */
            Item {
                id: loopBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                visible: root.loopOk
                opacity: root.loopNone ? 0.5 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                Rectangle {
                    anchors.fill: parent
                    radius: 5 * root.s
                    color: loopArea.containsMouse ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: loopArea.containsMouse
                        ? Theme.frameBorder
                        : (root.loopNone ? "transparent" : Qt.alpha(Theme.vermLit, root.loopTrack ? 0.5 : 0.8))
                }

                Text {
                    visible: Flags.showGlyphs
                    anchors.centerIn: parent
                    text: "循"
                    font.family: Theme.fontJp
                    font.pixelSize: 10 * root.s
                    color: root.loopNone ? Theme.dim : Theme.vermLit
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                GlyphIcon {
                    visible: !Flags.showGlyphs
                    anchors.centerIn: parent
                    width: 11 * root.s
                    height: 11 * root.s
                    name: "refresh"
                    color: root.loopNone ? Theme.dim : Theme.vermLit
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    id: oneBadge
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -2 * root.s
                    anchors.rightMargin: -2 * root.s
                    width: 5 * root.s
                    height: 5 * root.s
                    radius: width / 2
                    color: Theme.vermDeep
                    border.width: 1
                    border.color: Theme.cardTop
                    visible: root.loopTrack
                }

                MouseArea {
                    id: loopArea
                    anchors.fill: parent
                    anchors.margins: -5 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextLoop()
                }
            }

            Text {
                id: durLbl
                anchors.right: loopBtn.visible ? loopBtn.left : parent.right
                anchors.rightMargin: loopBtn.visible ? 7 * root.s : 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmt(root.lengthSec)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.features: { "tnum": 1 }
            }

            Canvas {
                id: stroke
                anchors.left: posLbl.right
                anchors.leftMargin: 7 * root.s
                anchors.right: durLbl.left
                anchors.rightMargin: 7 * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 11 * root.s

                readonly property real inset: 3 * root.s
                readonly property real usable: Math.max(1, width - 2 * inset)
                property real targetF: root.frac
                property real lastFrac: 0
                property real drawF: targetF
                readonly property real headX: inset + drawF * usable
                readonly property real headY: waveY(drawF)

                Behavior on drawF {
                    enabled: Math.abs(root.frac - stroke.lastFrac) < 0.02
                    NumberAnimation { duration: Math.round(500 * Motion.mult); easing.type: Easing.Linear }
                }
                onTargetFChanged: Qt.callLater(() => { stroke.lastFrac = root.frac; })

                onDrawFChanged: requestPaint()
                onWidthChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()

                function waveY(u) {
                    return height / 2 - 2.6 * Math.sin(3 * Math.PI * u) * Math.exp(-2.5 * u) * root.s;
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (width <= 0 || height <= 0)
                        return;
                    const n = 48;
                    ctx.strokeStyle = Theme.border;
                    ctx.lineWidth = 2.5 * root.s;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(inset, waveY(0));
                    for (let i = 1; i <= n; i++)
                        ctx.lineTo(inset + (i / n) * usable, waveY(i / n));
                    ctx.stroke();

                    if (drawF <= 0.002)
                        return;
                    const hTail = 2.5 * root.s;
                    const hHead = 1.75 * root.s;
                    const m = Math.max(2, Math.ceil(n * drawF));
                    ctx.fillStyle = Theme.verm;
                    ctx.beginPath();
                    ctx.arc(inset, waveY(0), hTail, Math.PI / 2, 3 * Math.PI / 2);
                    for (let i = 0; i <= m; i++) {
                        const u = (i / m) * drawF;
                        ctx.lineTo(inset + u * usable, waveY(u) - (hTail + (hHead - hTail) * (i / m)));
                    }
                    ctx.arc(headX, headY, hHead, -Math.PI / 2, Math.PI / 2);
                    for (let i = m; i >= 0; i--) {
                        const u = (i / m) * drawF;
                        ctx.lineTo(inset + u * usable, waveY(u) + (hTail + (hHead - hTail) * (i / m)));
                    }
                    ctx.closePath();
                    ctx.fill();
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.margins: -8 * root.s
                    enabled: root.hasPlayer && root.player.canSeek && root.player.positionSupported && root.lengthSec > 0 && !root.live
                    cursorShape: Qt.PointingHandCursor
                    function fracAt(mx) {
                        return Math.max(0, Math.min(1, (mx - 8 * root.s - stroke.inset) / stroke.usable));
                    }
                    onPressed: (e) => {
                        root.dragFrac = fracAt(e.x);
                        root.dragging = true;
                    }
                    onPositionChanged: (e) => { if (pressed) root.dragFrac = fracAt(e.x); }
                    onReleased: {
                        if (root.player)
                            root.player.position = root.dragFrac * root.lengthSec;
                        root.dragging = false;
                    }
                }
            }
        }

        /** Transport: kanji-skip, the play/pause seal, kanji-next. */
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * root.s
            height: 20 * root.s

            KanjiSkip {
                kanjiText: "前"
                icon: "prev"
                can: root.hasPlayer && root.player.canGoPrevious
                onActivated: if (root.player) root.player.previous()
            }

            Rectangle {
                id: seal
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.s
                height: 18 * root.s
                radius: 5 * root.s
                rotation: -1.5
                scale: 1 + 0.08 * root.sealPulse

                property real sat: root.playing ? 1 : 0
                Behavior on sat { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                opacity: (sealArea.enabled ? 1 : 0.4) * (0.75 + 0.25 * sat)
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, 0.4 + 0.4 * root.sealPulse)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.mix(Theme.verm, Theme.tileBg, 0.55 - 0.27 * seal.sat) }
                    GradientStop { position: 1.0; color: root.mix(Theme.vermDeep, Theme.tileBg, 0.55 - 0.27 * seal.sat) }
                }

                Text {
                    visible: Flags.showGlyphs
                    anchors.centerIn: parent
                    text: root.playing ? "奏" : "休"
                    color: Theme.bright
                    font.family: Theme.fontJp
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }

                GlyphIcon {
                    visible: !Flags.showGlyphs
                    anchors.centerIn: parent
                    width: 11 * root.s
                    height: 11 * root.s
                    name: root.playing ? "pause" : "play"
                    color: Theme.bright
                }

                MouseArea {
                    id: sealArea
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }

            KanjiSkip {
                kanjiText: "次"
                icon: "next"
                can: root.hasPlayer && root.player.canGoNext
                onActivated: if (root.player) root.player.next()
            }
        }
    }
}