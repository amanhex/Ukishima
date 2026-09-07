import QtQuick
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

Item {
    id: root

    property real s: 1
    property string screenName: ""
    property bool suppressed: false
    property bool expanded: false
    property bool flashing: false
    property string kind: "volume"
    property bool armed: false
    property int holdExtends: 0

    /**
     * The player the current flash speaks for. Normally the active source, but an
     * announce can point it at another player that just started, so a video over
     * your music still gets its own flash without stealing the surface.
     */
    property var pendingSubject: null
    readonly property var subject: pendingSubject ? pendingSubject : Players.active
    readonly property bool subjectHas: subject !== null
    readonly property bool subjectPlaying: subjectHas && subject.isPlaying
    readonly property string subjectTitle: subjectHas ? Players.refineTitle(subject, subject.trackTitle || Players.labelOf(subject)) : ""
    readonly property string subjectArtist: subjectHas ? Theme.joinArtists(subject.trackArtists, subject.trackArtist) : ""
    readonly property string subjectIcon: subjectHas ? Players.appIconFor(subject) : ""

    /** Subject art, live so a cover that lands a beat after the title still resolves; the key forces a reload when a browser reuses one file path. */
    readonly property string liveArt: {
        if (!subjectHas)
            return "";
        var u = Players.artUrlFor(subject);
        if (!u)
            return "";
        return u.indexOf("file:") === 0 ? u + "#" + Players.keyFor(subject) : u;
    }

    readonly property real brightness: Backlight.brightness
    property bool recordStarted: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(1, sink.audio.volume)) : 0

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property real micVolume: source && source.audio ? Math.max(0, Math.min(1, source.audio.volume)) : 0

    readonly property real desiredW: kind === "workspace" ? Math.max(120 * s, wsIndicator.implicitWidth + 40 * s)
        : (kind === "track" ? 344 * s : (kind === "record" ? 256 * s : 248 * s))
    readonly property real desiredH: kind === "track" ? 64 * s : 44 * s

    /**
     * Active workspace name on this monitor. Any switch (Super+arrow,
     * Super+wheel, clicking a dot) changes it, so flashing the workspace OSD
     * here briefly morphs the pill open to show where you landed. The arm timer
     * swallows the initial populate, so login doesn't flash. Skipped while the
     * pill is expanded: the hover/surface pill already shows the live dots with
     * the active one marked, so the OSD would only be a redundant morph.
     */
    readonly property string activeWsName: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "";
        return "";
    }
    onActiveWsNameChanged: if (activeWsName.length > 0 && !expanded) flash("workspace");

    /**
     * Media (track) flashes are intentionally disabled: a playing browser throws
     * an announce on every title/metadata churn, so any autoplaying feed
     * (YouTube Shorts, Instagram Reels) would pop the pill open on loop. The
     * media surface is the one now-playing view; no OSD flash for it.
     */

    /**
     * Every pill carries its own Osd but the volume/track/battery signals are
     * global, so without this gate one keypress flashes every monitor at once.
     * Workspace flashes skip it: those are already keyed to this screen's own
     * active workspace.
     */
    readonly property bool onFocusedMonitor: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName

    function flash(which) {
        if (!armed || suppressed)
            return false;
        if (which !== "workspace" && !onFocusedMonitor)
            return false;
        if (which === "track" && flashing && (kind === "volume" || kind === "brightness"))
            return false;
        if (which === "track")
            holdExtends = 0;
        kind = which;
        flashing = true;
        hideTimer.interval = (which === "battery" || which === "record") ? 2000 : 1800;
        hideTimer.restart();
        return true;
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop();
            flashing = false;
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: {
            if (root.kind === "track" && cover.status !== Image.Ready && root.liveArt.length > 0 && root.holdExtends < 5) {
                root.holdExtends++;
                hideTimer.interval = 350;
                hideTimer.restart();
            } else {
                root.flashing = false;
            }
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumesChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
    }

    Connections {
        target: root.source && root.source.audio ? root.source.audio : null
        function onMutedChanged() { root.flash("mic"); }
    }

    Connections {
        target: Players
        function onAnnounce(player) {
            root.pendingSubject = player;
        }
    }

    Connections {
        target: Battery
        enabled: Battery.present
        function onChargingChanged() {
            if (Battery.charging)
                root.flash("battery");
        }
    }

    Connections {
        target: ScreenRec
        function onRecordingChanged() {
            root.recordStarted = ScreenRec.recording;
            root.flash("record");
        }
    }

    Connections {
        target: Backlight
        function onChanged() {
            root.flash("brightness");
        }
    }

    Item {
        id: volRow
        anchors.fill: parent
        opacity: root.kind === "volume" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: volGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: root.muted ? "speaker-off" : "speaker"
            color: root.muted ? Theme.dim : Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: volPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.dim : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: volGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: volPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.volume
                radius: parent.radius
                color: root.muted ? Theme.vermDim : Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: micRow
        anchors.fill: parent
        opacity: root.kind === "mic" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: micGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: root.micMuted ? "mic-off" : "mic"
            color: root.micMuted ? Theme.dim : Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: micPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: root.micMuted ? "off" : Math.round(root.micVolume * 100) + "%"
            color: root.micMuted ? Theme.dim : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: micGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: micPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.micVolume
                radius: parent.radius
                color: root.micMuted ? Theme.vermDim : Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: trackRow
        anchors.fill: parent
        opacity: root.kind === "track" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 44 * root.s
            height: 44 * root.s
            radius: 9 * root.s
            color: Theme.tileBg

            Image {
                id: cover
                anchors.fill: parent
                source: root.kind === "track" ? root.liveArt : ""
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: String(source).indexOf("file:") !== 0
                opacity: status === Image.Ready ? 1 : 0
                /** Art that arrives late still earns a moment on screen, so a cover
                 *  decoded near the end of the flash is actually seen. */
                onStatusChanged: if (status === Image.Ready && root.flashing && root.kind === "track") {
                    hideTimer.interval = 1300;
                    hideTimer.restart();
                }
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: parent.width * 0.42
                height: width
                name: "music"
                color: Theme.subtle
                visible: cover.status !== Image.Ready
            }

            /** The source's own app icon, sat as a small badge on the art corner. */
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 3 * root.s
                width: 18 * root.s
                height: 18 * root.s
                radius: width / 2
                color: Qt.alpha(Theme.cardBot, 0.8)
                visible: srcIcon.status === Image.Ready

                Image {
                    id: srcIcon
                    anchors.centerIn: parent
                    width: 12 * root.s
                    height: 12 * root.s
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    source: root.kind === "track" ? root.subjectIcon : ""
                }
            }
        }

        GlyphIcon {
            id: trackCtrl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: root.subjectPlaying ? "play" : "pause"
            color: root.subjectPlaying ? Theme.vermLit : Theme.iconDim
        }

        Column {
            anchors.left: coverBox.right
            anchors.leftMargin: 12 * root.s
            anchors.right: trackCtrl.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            Text {
                width: parent.width
                text: root.subjectHas ? root.subjectTitle : "Nothing playing"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.subjectArtist
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                maximumLineCount: 1
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
    }

    Item {
        id: brightRow
        anchors.fill: parent
        opacity: root.kind === "brightness" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: brightGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: "sun"
            color: Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: brightPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.brightness * 100) + "%"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: brightGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: brightPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.brightness
                radius: parent.radius
                color: Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: batteryRow
        anchors.fill: parent
        opacity: root.kind === "battery" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: battGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: "bolt"
            color: Theme.flameGlow
            stroke: 1.7
        }

        Text {
            id: battPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 40 * root.s
            horizontalAlignment: Text.AlignRight
            text: Battery.pct + "%"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: battGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: battPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg
            clip: true

            Rectangle {
                id: battFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Battery.frac
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.vermDeep }
                    GradientStop { position: 1.0; color: Theme.flameGlow }
                }
                Behavior on width { NumberAnimation { duration: Motion.fast } }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 34 * root.s
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00ffffff" }
                        GradientStop { position: 0.5; color: "#55ffe6d6" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }

                    NumberAnimation on x {
                        from: -34 * root.s
                        to: battFill.width
                        duration: 1200
                        loops: Animation.Infinite
                        running: root.kind === "battery" && Battery.charging
                    }
                }
            }
        }
    }

    Item {
        id: workspaceRow
        anchors.fill: parent
        opacity: root.kind === "workspace" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Workspaces {
            id: wsIndicator
            anchors.centerIn: parent
            screenName: root.screenName
            s: root.s
            gap: 8 * root.s
            enabled: false
            /** The hidden pill OSD controller is disabled, so stop it from
             *  spawning sh + hyprctl on every workspace event. The popup OSD
             *  stays enabled and keeps its watcher live for fresh dots. */
            watch: root.enabled
        }
    }

    Item {
        id: recordRow
        anchors.fill: parent
        opacity: root.kind === "record" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            id: recGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * root.s
            height: 13 * root.s
            radius: width / 2
            color: root.recordStarted ? Theme.verm : Theme.dim

            SequentialAnimation on opacity {
                running: root.recordStarted && root.kind === "record"
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.left: recGlyph.right
            anchors.leftMargin: 13 * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordStarted ? "Recording started" : "Recording stopped"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
