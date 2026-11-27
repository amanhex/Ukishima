import QtQuick
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * Transient OSD face, shared by every display mode.
 *
 * A compact horizontal pill (swayosd/Hyprland style): small glyph, a thin
 * level bar and the value, one row. Volume, mic, brightness and battery all
 * use the same face; recording swaps the bar for a pulsing dot and a label,
 * and the workspace flash keeps its compact dots. One design, no per-mode
 * card variants — the host only chooses where the pill appears.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""
    property bool suppressed: false
    property bool expanded: false
    property bool flashing: false
    property string kind: "volume"
    property bool workspaceFlash: true
    property bool armed: false

    readonly property real brightness: Backlight.brightness
    property bool recordStarted: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(1, sink.audio.volume)) : 0

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property real micVolume: source && source.audio ? Math.max(0, Math.min(1, source.audio.volume)) : 0

    /**
     * Active workspace name on this monitor. Any switch changes it, so flashing
     * the workspace OSD briefly shows where you landed. The arm timer swallows
     * the initial populate, so login doesn't flash. Skipped while the pill is
     * expanded, and in waybar mode (the bar already shows the live numbers).
     */
    readonly property string activeWsName: Wm.activeWorkspaceName(screenName)
    onActiveWsNameChanged: if (workspaceFlash && activeWsName.length > 0 && !expanded) flash("workspace");

    readonly property bool onFocusedMonitor: Wm.screenFocused(screenName)

    // ── The single pill face ────────────────────────────────────────────────
    readonly property real desiredW: kind === "workspace"
        ? Math.max(120 * s, wsIndicator.implicitWidth + 40 * s)
        : (kind === "record" ? 150 * s : 208 * s)
    readonly property real desiredH: kind === "workspace" ? 40 * s : 40 * s

    readonly property bool levelMuted: kind === "volume" ? muted : (kind === "mic" ? micMuted : false)
    readonly property real level: {
        if (kind === "mic") return micVolume;
        if (kind === "brightness") return brightness;
        if (kind === "battery") return Battery.frac;
        return volume;
    }
    readonly property color levelColor: levelMuted ? Theme.vermDim
        : (kind === "brightness" || kind === "battery") ? Theme.flameGlow : Theme.vermLit
    readonly property string glyph: kind === "mic" ? (micMuted ? "mic-off" : "mic")
        : kind === "brightness" ? "sun"
        : kind === "battery" ? "bolt"
        : (muted ? "speaker-off" : "speaker")
    readonly property string pctText: kind === "mic" ? (micMuted ? "off" : Math.round(micVolume * 100) + "%")
        : kind === "brightness" ? Math.round(brightness * 100) + "%"
        : kind === "battery" ? Battery.pct + "%"
        : (muted ? "off" : Math.round(volume * 100) + "%")

    function flash(which) {
        if (!armed || suppressed)
            return false;
        if (which !== "workspace" && !onFocusedMonitor)
            return false;
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
        onTriggered: root.flashing = false
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

    /**
     * The pill row: glyph, level bar, value. Record swaps the bar for a dot
     * and a label.
     */
    Item {
        id: hudFace
        anchors.fill: parent
        visible: root.kind !== "workspace"

        GlyphIcon {
            id: hudGlyph
            anchors.left: parent.left
            anchors.leftMargin: 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: root.glyph
            color: root.levelMuted ? Theme.dim : Theme.cream
            stroke: 1.7
            visible: root.kind !== "record"
        }

        Text {
            id: hudPct
            visible: root.kind !== "record"
            anchors.right: parent.right
            anchors.rightMargin: 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.pctText
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            id: hudTrack
            visible: root.kind !== "record"
            anchors.left: hudGlyph.right
            anchors.leftMargin: 10 * root.s
            anchors.right: hudPct.left
            anchors.rightMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 5 * root.s
            radius: height / 2
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, root.level))
                radius: parent.radius
                color: root.levelColor
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 15 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 10 * root.s
            height: width
            radius: width / 2
            color: root.recordStarted ? Theme.verm : Theme.dim
            visible: root.kind === "record"

            SequentialAnimation on opacity {
                running: root.kind === "record" && root.recordStarted
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        Text {
            visible: root.kind === "record"
            anchors.left: parent.left
            anchors.leftMargin: 34 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.recordStarted ? "Recording" : "Stopped"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }
    }

    /** The workspace flash keeps its compact dots. */
    Item {
        id: workspaceRow
        anchors.fill: parent
        visible: root.kind === "workspace"

        Workspaces {
            id: wsIndicator
            anchors.centerIn: parent
            screenName: root.screenName
            s: root.s
            gap: 8 * root.s
            enabled: false
        }
    }
}
