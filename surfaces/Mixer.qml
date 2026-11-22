import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * Mixer surface: header with the device pickers and Keep-Awake / Night-light /
 * Game-mode chips, and a row of four vertical ink-faders wired to real
 * hardware (brightness via ddcutil, vibrance via nvibrant, volume and mic via
 * Pipewire). Fills the lower body of the pill.
 */
PillSurface {
    id: root

    /**
     * Mixer fader style, chosen on the Surface Styles page: "default" is the
     * filament fader; the rest borrow the Chaldea slider tracks — "comb",
     * "slats", "stipple", "weave".
     */
    readonly property string style: ["comb", "slats", "stipple", "weave"].indexOf(Flags.styleMixer) >= 0 ? Flags.styleMixer : "default"
    readonly property bool styled: root.style !== "default"
    /** Slats and weave lay the channels out as horizontal rows. */
    readonly property bool horizontalStyle: root.style === "slats" || root.style === "weave"

    /** Chaldea designs sit on a flat 16*s inset, matching the media and sysmon layouts. */
    mTop: root.styled ? 16 : 13
    mLeft: root.styled ? 16 : 14
    mRight: root.styled ? 16 : 14
    mBottom: root.styled ? 16 : 12

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    /** Ask the pill to open another surface; wired so the header's music glyph can open Sound. */
    signal requestSurface(string name)

    property int focusIndex: -1
    readonly property int faderCount: faders.length
    readonly property var faders: {
        void brRep.count;
        void blLoader.item;
        var out = [];
        for (var i = 0; i < brRep.count; i++) {
            var f = brRep.itemAt(i);
            if (f)
                out.push(f);
        }
        if (blLoader.item)
            out.push(blLoader.item);
        out.push(vibFader, volFader, micFader);
        return out;
    }
    readonly property bool surfaceHovered: hoverTracker.hovered

    /**
     * Tick centre of the focused fader, mapped into this mixer's root so the
     * bead glides as keyboard/hover focus moves across the row. Layout deps are
     * voided before mapToItem so the binding re-evaluates on resize (else stale).
     */
    readonly property point focusTickPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        const i = Math.max(0, Math.min(faders.length - 1, root.focusIndex));
        const f = faders[i];
        if (!f)
            return Qt.point(0, 0);
        return f.mapToItem(root, f.tickCenter.x, f.tickCenter.y);
    }

    ameForm: "tick"
    amePoint: focusTickPoint

    /**
     * Pointer-driven fader targeting. MouseArea hover is flaky on this
     * layer-shell surface, so a non-blocking HoverHandler is the only hover
     * source. Its pointer x maps to a fader column and drives keyboard focus.
     */
    readonly property int hoverIndex: surfaceHovered && width > 0 && faders.length > 0
        && hoverTracker.point.position.y >= faderRow.y
        ? Math.max(0, Math.min(faders.length - 1, Math.floor(root.horizontalStyle
            ? (hoverTracker.point.position.y - faderRow.y) / Math.max(1, faderRow.height) * faders.length
            : hoverTracker.point.position.x / (width / faders.length))))
        : -1
    onHoverIndexChanged: if (hoverIndex >= 0 && !keyLatch.running) focusIndex = hoverIndex

    HoverHandler {
        id: hoverTracker
    }

    /**
     * Brief keyboard-nav precedence: an arrow keypress latches focus for
     * Motion.standard so a stray pointer move doesn't yank the target away
     * mid-navigation. Hover resumes driving focus once it lapses.
     */
    Timer {
        id: keyLatch
        interval: Motion.standard
    }

    onActiveChanged: focusIndex = active ? 0 : -1

    /**
     * Nudge the focused fader by `deltaPct` percent. Returns true when a fader
     * handled the step.
     */
    function stepFocused(deltaPct) {
        if (focusIndex < 0)
            return false;
        faders[focusIndex].step(deltaPct);
        keyLatch.restart();
        return true;
    }

    /**
     * Move keyboard focus across the fader row, wrapping at the ends. `dir` is +1
     * (right) or -1 (left); a fresh focus lands on the first or last fader.
     */
    function moveFocus(dir) {
        focusIndex = focusIndex < 0 ? (dir > 0 ? 0 : faders.length - 1)
                                    : (focusIndex + dir + faders.length) % faders.length;
        keyLatch.restart();
    }

    Component.onCompleted: Devices.detect()

    property real pendingVibrance: -1
    property int pendingBacklight: -1

    Timer {
        id: vibDebounce
        interval: 160
        onTriggered: if (root.pendingVibrance >= 0) {
            Devices.setVibrance(root.pendingVibrance);
            root.pendingVibrance = -1;
        }
    }

    Timer {
        id: blDebounce
        interval: 160
        onTriggered: if (root.pendingBacklight >= 0) {
            Devices.setBacklight(root.pendingBacklight);
            root.pendingBacklight = -1;
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    /**
     * Keep the internal-backlight fader live: Devices.backlightPct is only
     * written at startup and on drag, so keyboard changes (swayosd writing the
     * same sysfs node) never showed up. The Backlight poller sees those writes
     * within its 1s loop and this mirrors the reading into the fader's value.
     */
    Connections {
        target: Backlight
        function onChanged() {
            Devices.backlightPct = Math.round(Backlight.brightness * 100);
        }
    }

    component IconChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        property string tipTitle: ""
        property string tipDesc: ""
        signal toggled()

        width: (root.styled ? 22 : 26) * root.s
        height: (root.styled ? 22 : 26) * root.s
        radius: root.styled ? 0 : 8 * root.s
        color: chip.on ? (root.styled ? Qt.alpha(Theme.vermLit, 0.18) : Theme.frameBg) : "transparent"
        border.width: 1
        border.color: chip.on ? (root.styled ? Theme.vermLit : Theme.frameBorder) : (root.styled ? Qt.alpha(Theme.cream, 0.22) : Theme.border)

        GlyphIcon {
            anchors.centerIn: parent
            width: (root.styled ? 12 : 15) * root.s
            height: (root.styled ? 12 : 15) * root.s
            name: chip.glyph
            color: root.styled ? (chip.on ? Theme.vermLit : Theme.subtle) : (chip.on ? Theme.vermLit : Theme.iconDim)
            stroke: 1.7
        }
        HoverHandler {
            id: chipHover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: chip.tipTitle
            desc: chip.tipDesc
            show: chipHover.hovered
        }
    }

    /**
     * Header: wordmark on the left, device and toggle chips on the right. Each
     * design names itself here; the fader field below carries its identity.
     */
    Item {
        id: header
        z: 5
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs || root.styled
                text: "調"
                color: root.styled ? Theme.vermLit : Theme.cream
                font.family: Theme.fontJp
                font.weight: Theme.fontJpWeight
                font.pixelSize: (root.styled ? 13 : 16) * root.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.styled ? "MIX // " + root.style.toUpperCase() : "MIXER"
                color: root.styled ? Theme.subtle : Theme.subtle
                font.family: root.styled ? Theme.fontMono : Theme.font
                font.pixelSize: (root.styled ? 9 : 10) * root.s
                font.weight: root.styled ? Font.Normal : Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: (root.styled ? 1 : 1.6) * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s
            IconChip {
                glyph: "music"
                tipTitle: "Sound"
                tipDesc: "Equalizer, apps & mic"
                onToggled: root.requestSurface("sound")
            }
            IconChip {
                glyph: "awake"
                on: Flags.keepAwake
                tipTitle: "Keep awake"
                tipDesc: "Block sleep & screen-off"
                onToggled: Flags.keepAwake = !Flags.keepAwake
            }
            IconChip {
                glyph: "sun"
                visible: Wm.caps.nightLight
                on: Flags.nightLightMode !== "off"
                tipTitle: "Night light"
                tipDesc: "Warm the screen"
                onToggled: NightLight.setMode(Flags.nightLightMode === "off" ? "on" : "off")
            }
            IconChip {
                glyph: "gamepad"
                on: Flags.gameMode
                tipTitle: "Game mode"
                tipDesc: Wm.caps.gameModeStrip ? "Strip effects, quiet the desktop" : "Quiet the desktop"
                onToggled: Flags.gameMode = !Flags.gameMode
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: root.styled ? Theme.border : Theme.hair
    }

    /**
     * Per-design fader field, drawn behind the faders. Comb gets chart rules,
     * stipple dotted column separators; the horizontal designs get full-width
     * rows — slats a rule per channel, weave alternating bands — plus a red
     * focus bar on the active row.
     */
    Item {
        id: field
        visible: root.styled
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 142 * root.s

        readonly property real colW: width / Math.max(1, root.faderCount)
        readonly property real rowH: height / Math.max(1, root.faderCount)

        // comb: the header divider is the field's only rule, so the top and the
        // foot stay open rather than framing the faders twice.

        // stipple: dotted column separators
        Repeater {
            model: root.style === "stipple" ? Math.max(0, root.faderCount - 1) : 0

            Item {
                required property int index
                x: (index + 1) * field.colW - 1 * root.s
                width: 2 * root.s
                height: field.height
                clip: true

                Repeater {
                    model: Math.ceil(field.height / (6 * root.s))
                    Rectangle {
                        y: index * 6 * root.s
                        width: 2 * root.s
                        height: 2 * root.s
                        radius: 1 * root.s
                        color: Qt.alpha(Theme.cream, 0.22)
                    }
                }
            }
        }

        // slats / weave: channel rows
        Repeater {
            model: root.horizontalStyle ? root.faderCount : 0

            Item {
                required property int index
                y: index * field.rowH
                width: field.width
                height: field.rowH

                Rectangle {
                    anchors.fill: parent
                    visible: root.style === "weave" && index % 2 === 1
                    color: Qt.alpha(Theme.cream, 0.03)
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.hair
                }

                Rectangle {
                    visible: index === root.focusIndex
                    width: 3 * root.s
                    height: parent.height
                    color: Theme.vermLit
                }
            }
        }
    }

    Item {
        id: faderRow
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 142 * root.s

        readonly property real colW: width / Math.max(1, root.faderCount)
        readonly property real rowH: height / Math.max(1, root.faderCount)

        Repeater {
            id: brRep
            model: Devices.ddcMonitors

            VFader {
                id: brFader

                required property var modelData
                required property int index

                property int pct: 75
                property real pendingPct: -1

                x: root.horizontalStyle ? 0 : index * faderRow.colW
                y: root.horizontalStyle ? index * faderRow.rowH : 0
                width: root.horizontalStyle ? faderRow.width : faderRow.colW
                s: root.s
                pattern: root.styled ? root.style : ""
                horizontal: root.horizontalStyle
                mirror: root.style === "weave"
                readoutAbove: root.style === "stipple"
                bigReadout: root.style === "stipple"
                icon: "sun"
                subLabel: modelData.label
                subPersistent: true
                focused: root.focusIndex === index
                value: pct / 100
                valueLabel: pct + "%"
                onMoved: (v) => pct = Math.max(5, Math.min(100, Math.round(v * 100)))
                onCommitted: (v) => {
                    pendingPct = Math.max(5, Math.min(100, Math.round(v * 100)));
                    brCommit.restart();
                }

                Timer {
                    id: brCommit
                    interval: 160
                    onTriggered: if (brFader.pendingPct >= 0) {
                        Devices.setBrightness(brFader.modelData.bus, brFader.pendingPct);
                        brFader.pendingPct = -1;
                    }
                }

                Process {
                    id: brRead
                    command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", brFader.modelData.bus, "--brief"]
                    running: true
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var v = Devices.parseBrightness(this.text);
                            if (v >= 0)
                                brFader.pct = v;
                        }
                    }
                }
            }
        }

        Loader {
            id: blLoader
            active: Devices.backlightPresent
            visible: active
            x: root.horizontalStyle ? 0 : brRep.count * faderRow.colW
            y: root.horizontalStyle ? brRep.count * faderRow.rowH : 0
            width: active ? (root.horizontalStyle ? faderRow.width : faderRow.colW) : 0

            sourceComponent: VFader {
                width: root.horizontalStyle ? faderRow.width : faderRow.colW
                height: root.horizontalStyle ? faderRow.rowH : implicitHeight
                s: root.s
                horizontal: root.horizontalStyle
                mirror: root.style === "weave"
                readoutAbove: root.style === "stipple"
                bigReadout: root.style === "stipple"
                pattern: root.styled ? root.style : ""
                icon: "sun"
                subLabel: "Built-in"
                subPersistent: true
                focused: root.focusIndex === brRep.count
                value: Devices.backlightPct / 100
                valueLabel: Devices.backlightPct + "%"
                onMoved: (v) => Devices.backlightPct = Math.max(1, Math.min(100, Math.round(v * 100)))
                onCommitted: (v) => { root.pendingBacklight = Math.max(1, Math.min(100, Math.round(v * 100))); blDebounce.restart(); }
            }
        }

        VFader {
            id: vibFader
            x: root.horizontalStyle ? 0 : (root.faderCount - 3) * faderRow.colW
            y: root.horizontalStyle ? (root.faderCount - 3) * faderRow.rowH : 0
            width: root.horizontalStyle ? faderRow.width : faderRow.colW
            height: root.horizontalStyle ? faderRow.rowH : implicitHeight
            s: root.s
            pattern: root.styled ? root.style : ""
            horizontal: root.horizontalStyle
            mirror: root.style === "weave"
            readoutAbove: root.style === "stipple"
            bigReadout: root.style === "stipple"
            icon: "monitor"
            subLabel: "Vibrance"
            subPersistent: true
            focused: root.focusIndex === root.faderCount - 3
            value: Devices.vibrance / 100
            valueLabel: Devices.vibrance + "%"
            onMoved: (v) => Devices.vibrance = Math.round(v * 100)
            onCommitted: (v) => { root.pendingVibrance = v * 100; vibDebounce.restart(); }
        }
        VFader {
            id: volFader
            x: root.horizontalStyle ? 0 : (root.faderCount - 2) * faderRow.colW
            y: root.horizontalStyle ? (root.faderCount - 2) * faderRow.rowH : 0
            width: root.horizontalStyle ? faderRow.width : faderRow.colW
            height: root.horizontalStyle ? faderRow.rowH : implicitHeight
            s: root.s
            pattern: root.styled ? root.style : ""
            horizontal: root.horizontalStyle
            mirror: root.style === "weave"
            readoutAbove: root.style === "stipple"
            bigReadout: root.style === "stipple"
            icon: (root.sink && root.sink.audio && root.sink.audio.muted) ? "speaker-off" : "speaker"
            subLabel: "Volume"
            subPersistent: true
            focused: root.focusIndex === root.faderCount - 2
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            valueLabel: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
            muted: root.sink && root.sink.audio ? root.sink.audio.muted : false
            onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
        }
        VFader {
            id: micFader
            x: root.horizontalStyle ? 0 : (root.faderCount - 1) * faderRow.colW
            y: root.horizontalStyle ? (root.faderCount - 1) * faderRow.rowH : 0
            width: root.horizontalStyle ? faderRow.width : faderRow.colW
            height: root.horizontalStyle ? faderRow.rowH : implicitHeight
            s: root.s
            pattern: root.styled ? root.style : ""
            horizontal: root.horizontalStyle
            mirror: root.style === "weave"
            readoutAbove: root.style === "stipple"
            bigReadout: root.style === "stipple"
            icon: (root.source && root.source.audio && root.source.audio.muted) ? "mic-off" : "mic"
            subLabel: "Microphone"
            subPersistent: true
            focused: root.focusIndex === root.faderCount - 1
            value: root.source && root.source.audio ? root.source.audio.volume : 0
            valueLabel: (root.source && root.source.audio && root.source.audio.muted)
                ? "off"
                : (Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%")
            muted: root.source && root.source.audio ? root.source.audio.muted : false
            onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }
            onIconClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }

            MouseArea {
                id: micMute
                visible: !root.horizontalStyle
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * root.s
                height: 22 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
            }
        }
    }

    /**
     * Chaldea chassis ticks, 10*s in from the card edge. This item sits inside
     * the PillSurface margins, so the offsets cancel those insets to line up
     * with the media card's ticks.
     */
    Item {
        anchors.fill: parent
        visible: root.styled
        z: 20

        readonly property real xl: (10 - root.mLeft) * root.s
        readonly property real yt: (10 - root.mTop) * root.s
        readonly property real xr: (10 - root.mRight) * root.s
        readonly property real yb: (10 - root.mBottom) * root.s

        Rectangle { x: parent.xl; y: parent.yt; width: 4 * root.s; height: 1; color: Theme.vermLit }
        Rectangle { x: parent.xl; y: parent.yt; width: 1; height: 4 * root.s; color: Theme.vermLit }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; y: parent.yt; width: 4 * root.s; height: 1; color: Theme.vermLit }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; y: parent.yt; width: 1; height: 4 * root.s; color: Theme.vermLit }
        Rectangle { x: parent.xl; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 4 * root.s; height: 1; color: Theme.vermLit }
        Rectangle { x: parent.xl; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 1; height: 4 * root.s; color: Theme.vermLit }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 4 * root.s; height: 1; color: Theme.vermLit }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 1; height: 4 * root.s; color: Theme.vermLit }
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0 && root.stepFocused(notches * 5))
                acc -= notches;
            event.accepted = true;
        }
    }
}
