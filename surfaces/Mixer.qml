import QtQuick
import QtQuick.Effects
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

    mTop: 13
    mLeft: 14
    mRight: 14
    mBottom: 12

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    /**
     * Output devices the user can make default: real sinks only, never the
     * per-app playback streams. Sorted by label so the list order stays stable
     * as nodes appear and vanish.
     */
    readonly property var outputSinks: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        out.sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b)));
        return out;
    }

    /**
     * Input devices the user can make default: real sources only. The sink
     * monitors that Pipewire exposes alongside real mics also match isSink=false,
     * so they are dropped by name to keep the list to actual capture devices.
     */
    readonly property var inputSources: {
        void Pipewire.nodes.values;
        var out = [];
        var all = Pipewire.nodes.values;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && !n.isSink && !n.isStream && n.audio && !/monitor/i.test(n.name || ""))
                out.push(n);
        }
        out.sort((a, b) => root.deviceLabel(a).localeCompare(root.deviceLabel(b)));
        return out;
    }

    function deviceLabel(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "";
    }

    /** Which device dropdown is open: "out", "in", or "" for none. */
    property string openPicker: ""

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

    onActiveChanged: {
        focusIndex = active ? 0 : -1;
        if (!active)
            openPicker = "";
    }

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
        objects: [root.sink, root.source].concat(root.outputSinks).concat(root.inputSources).filter(Boolean)
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
        color: chip.on ? (root.styled ? Qt.alpha(Theme.accent, 0.18) : Theme.frameBg) : "transparent"
        border.width: 1
        border.color: chip.on ? (root.styled ? Theme.accent : Theme.frameBorder) : (root.styled ? Qt.alpha(Theme.cream, 0.22) : Theme.border)

        GlyphIcon {
            anchors.centerIn: parent
            width: (root.styled ? 12 : 15) * root.s
            height: (root.styled ? 12 : 15) * root.s
            name: chip.glyph
            color: root.styled ? (chip.on ? Theme.accent : Theme.subtle) : (chip.on ? Theme.vermLit : Theme.iconDim)
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
     * Header device picker: an icon-only button that toggles its dropdown. It
     * reads as an open field (onGlow tint and border) while its list is showing,
     * the same affordance the display surface uses, so no chevron is needed.
     */
    component DevicePickerChip: Rectangle {
        id: dchip
        property string glyph: ""
        property bool open: false
        property string tip: ""
        signal toggled()

        width: (root.styled ? 22 : 26) * root.s
        height: (root.styled ? 22 : 26) * root.s
        radius: root.styled ? 0 : 8 * root.s
        color: root.styled
            ? (dchip.open ? Qt.alpha(Theme.accent, 0.18) : (dchipHover.hovered ? Theme.cardTop : "transparent"))
            : (dchip.open ? Qt.alpha(Theme.onGlow, 0.14) : (dchipHover.hovered ? Theme.frameBg : "transparent"))
        border.width: 1
        border.color: root.styled
            ? (dchip.open ? Theme.accent : Qt.alpha(Theme.cream, 0.22))
            : (dchip.open ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border)
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            anchors.centerIn: parent
            width: (root.styled ? 12 : 15) * root.s
            height: (root.styled ? 12 : 15) * root.s
            name: dchip.glyph
            color: root.styled ? (dchip.open ? Theme.accent : Theme.subtle) : (dchip.open ? Theme.vermLit : Theme.iconDim)
            stroke: 1.7
        }
        HoverHandler {
            id: dchipHover
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: dchip.toggled()
        }

        Tooltip {
            s: root.s
            placement: "below"
            title: dchip.tip
            show: dchipHover.hovered && !dchip.open
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
                color: root.styled ? Theme.accent : Theme.cream
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
            DevicePickerChip {
                glyph: "speaker"
                open: root.openPicker === "out"
                tip: "Output device"
                onToggled: root.openPicker = root.openPicker === "out" ? "" : "out"
            }
            DevicePickerChip {
                glyph: "mic"
                open: root.openPicker === "in"
                tip: "Input device"
                onToggled: root.openPicker = root.openPicker === "in" ? "" : "in"
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
     * Device dropdown overlay. Both the output and input pickers reuse this: the
     * `kind` ("out"/"in") keys it to root.openPicker, `model` is the node list,
     * `current` is the active default, and `onPick` writes the matching
     * preferredDefault. It floats above the faders right-aligned under the header
     * so the mixer height stays fixed while a list is open.
     */
    component DeviceMenu: Item {
        id: menu
        property string kind: ""
        property var model: []
        property var current
        signal pick(var node)

        readonly property bool open: root.openPicker === kind
        z: 7
        visible: open
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.right: parent.right
        width: 300 * root.s
        height: panel.height

        /**
         * Shadow caster kept apart from the option text. A layer over the labels
         * would rasterise the glyphs and soften them, so the halo lives on this
         * textless backing rect and the panel above stays unlayered and crisp.
         */
        Rectangle {
            anchors.fill: panel
            visible: menu.open
            radius: panel.radius
            color: Theme.cardBot
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Rectangle {
            id: panel
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(menu.model.length * 24 * root.s + 4 * root.s, 150 * root.s)
            clip: true
            radius: root.styled ? 0 : 9 * root.s
            color: Theme.cardBot
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.styled ? Theme.tileBg : Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            border.width: 1
            border.color: root.styled ? Theme.border : Theme.frameBorder

            ListView {
                anchors.fill: parent
                anchors.margins: 2 * root.s
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: menu.model

                delegate: Rectangle {
                    id: devRow
                    required property var modelData
                    readonly property bool current: menu.current === modelData

                    width: ListView.view.width
                    height: 24 * root.s
                    radius: root.styled ? 0 : 7 * root.s
                    color: root.styled
                        ? (devRowHover.hovered ? Theme.cardTop : (devRow.current ? Qt.alpha(Theme.accent, 0.16) : "transparent"))
                        : (devRowHover.hovered ? Theme.frameBg : (devRow.current ? Qt.alpha(Theme.onGlow, 0.16) : "transparent"))

                    HoverHandler { id: devRowHover }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 9 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.deviceLabel(devRow.modelData)
                        elide: Text.ElideRight
                        color: root.styled
                            ? (devRow.current ? Theme.cream : Theme.subtle)
                            : (devRow.current ? Theme.cream : Theme.subtle)
                        font.family: root.styled ? Theme.fontMono : Theme.font
                        font.pixelSize: (root.styled ? 9 : 10.5) * root.s
                        font.weight: root.styled ? Font.Normal : (devRow.current ? Font.Bold : Font.Medium)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menu.pick(devRow.modelData);
                            root.openPicker = "";
                        }
                    }
                }
            }
        }
    }

    DeviceMenu {
        kind: "out"
        model: root.outputSinks
        current: root.sink
        onPick: (node) => Pipewire.preferredDefaultAudioSink = node
    }

    DeviceMenu {
        kind: "in"
        model: root.inputSources
        current: root.source
        onPick: (node) => Pipewire.preferredDefaultAudioSource = node
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
                    color: Theme.accent
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

        Rectangle { x: parent.xl; y: parent.yt; width: 4 * root.s; height: 1; color: Theme.accent }
        Rectangle { x: parent.xl; y: parent.yt; width: 1; height: 4 * root.s; color: Theme.accent }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; y: parent.yt; width: 4 * root.s; height: 1; color: Theme.accent }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; y: parent.yt; width: 1; height: 4 * root.s; color: Theme.accent }
        Rectangle { x: parent.xl; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 4 * root.s; height: 1; color: Theme.accent }
        Rectangle { x: parent.xl; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 1; height: 4 * root.s; color: Theme.accent }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 4 * root.s; height: 1; color: Theme.accent }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: parent.xr; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.yb; width: 1; height: 4 * root.s; color: Theme.accent }
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
