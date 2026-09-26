pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 泊 DOCK sub-surface: the bottom app dock — its on/off switch and the dock's
 * own auto-hide, theme, glass depth and minimal flavour. The dock theme row
 * mirrors the pill's Theme surface (light / dark / dynamic / manual) so the
 * dock can hold its own palette independently of the pill; dynamic and manual
 * rebuild the shared rice palette through wallcolors.py exactly like the pill
 * does. Reached from the Appearance index and folds back to it on the back
 * chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    /** Current theme key; legacy "auto"/"transparent" saves read as dark. */
    readonly property string themeShown: (Flags.dockTheme === "auto"
        || Flags.dockTheme === "transparent") ? "dark" : Flags.dockTheme
    //* The glass depth axis is independent; legacy saves default to transparent.
    readonly property string glassShown: Flags.dockStyle === "solid" ? "solid" : "transparent"

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: {
        var c = accentColor;
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return ("#" + h(c.r) + h(c.g) + h(c.b)).toUpperCase();
    }

    function applyManual() {
        hueArg = String(Math.round(Flags.manualHue));
        modeArg = Flags.manualDark ? "dark" : "light";
        satArg = String(Flags.manualSat);
        applyTimer.restart();
    }

    function applyMode(v) {
        Flags.dockTheme = v;
        if (v === "manual")
            root.applyManual();
        else if (v === "dynamic")
            dynamicProc.running = true;
    }

    Timer {
        id: applyTimer
        interval: 260
        repeat: false
        onTriggered: paletteProc.running = true
    }

    Process {
        id: paletteProc
        command: ["sh", "-c",
            "wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; python3 \"$wallscript\" --hue \"$1\" \"$2\" \"$3\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1; command -v kitty >/dev/null 2>&1 && kitty @ set-colors \"$HOME/.cache/ukishima/kitty-colors\" >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    Process {
        id: dynamicProc
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper\"; pic=$(cat \"$f\" 2>/dev/null); case \"$pic\" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-still.png\";; esac; wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; [ -f \"$pic\" ] && python3 \"$wallscript\" \"$pic\" >/dev/null 2>&1; hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1; command -v kitty >/dev/null 2>&1 && kitty @ set-colors \"$HOME/.cache/ukishima/kitty-colors\" >/dev/null 2>&1 || true"]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.dockTheme === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Flags.dockTheme === "manual")
                root.applyManual();
        }
    }

    rows: {
        var base = [
            { item: dockRow, kind: "toggle", get: function () { return Flags.dockEnabled; }, set: function (v) { Flags.dockEnabled = v; } }
        ];
        // The dock sub-settings only exist while the dock itself is switched on.
        if (Flags.dockEnabled)
            base.push(
                { item: dockAutoHideRow, kind: "toggle", get: function () { return Flags.dockAutoHide; }, set: function (v) { Flags.dockAutoHide = v; } },
                { item: dockThemeRow, kind: "seg", vals: ["light", "dark", "dynamic", "manual"], get: function () { return root.themeShown; }, set: function (v) { root.applyMode(v); } },
                { item: dockGlassRow, kind: "seg", vals: ["transparent", "solid"], get: function () { return root.glassShown; }, set: function (v) { Flags.dockStyle = v; } },
                { item: dockMinimalRow, kind: "toggle", get: function () { return Flags.dockMinimal; }, set: function (v) { Flags.dockMinimal = v; } }
            );
        return base;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "泊"
            title: "DOCK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: dockRow
            surface: root
            name: "Dock"
            icon: "dock"
            last: !Flags.dockEnabled

            LinkToggle {
                s: root.s
                on: Flags.dockEnabled
                onToggled: Flags.dockEnabled = !Flags.dockEnabled
            }
        }

        SettingsRow {
            id: dockAutoHideRow
            surface: root
            name: "Dock auto-hide"
            icon: "eye-off"
            visible: Flags.dockEnabled

            LinkToggle {
                s: root.s
                on: Flags.dockAutoHide
                onToggled: Flags.dockAutoHide = !Flags.dockAutoHide
            }
        }

        SettingsRow {
            id: dockThemeRow
            surface: root
            name: "Dock theme"
            icon: "palette"
            visible: Flags.dockEnabled

            SettingsSeg {
                s: root.s
                options: [{ label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: root.themeShown
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, folded shut unless the dock theme is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. Mirrors the pill's Theme
         * surface so the dock can be rice-coloured independently of the pill.
         */
        Item {
            id: manualSection
            width: parent.width
            height: (Flags.dockEnabled && Flags.dockTheme === "manual") ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 14 * root.s

                    Rectangle {
                        id: hueStrip
                        anchors.fill: parent
                        radius: 7 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                        }

                        Rectangle {
                            id: hueThumb
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: (Flags.manualHue / 359) * (hueStrip.width - width)
                            color: root.accentColor
                            border.width: 2.5 * root.s
                            border.color: Theme.cream
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setHue(mx) {
                                if (Flags.manualSat < 0.05)
                                    Flags.manualSat = 0.5;
                                Flags.manualHue = Math.round(Math.max(0, Math.min(1, mx / hueStrip.width)) * 359);
                            }
                            onPressed: (mouse) => setHue(mouse.x)
                            onPositionChanged: (mouse) => setHue(mouse.x)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, toneSeg.implicitHeight)

                    Rectangle {
                        id: accentSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColor
                        border.width: 1
                        border.color: Theme.border
                    }

                    Column {
                        anchors.left: accentSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.right: toneSeg.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.manualDark ? "dark" : "light")
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.manualDark
                        onPicked: (v) => { Flags.manualDark = v; root.applyManual(); }
                    }
                }

                Item {
                    width: parent.width
                    height: 30 * root.s

                    Text {
                        id: hexHint
                        anchors.left: parent.left
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: hexField
                        anchors.left: hexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        placeholderText: root.currentHex
                        placeholderTextColor: Theme.faint
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 7

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var raw = text.trim();
                            var clean = raw.charAt(0) === "#" ? raw.slice(1) : raw;
                            if (/^[0-9a-fA-F]{6}$/.test(clean)) {
                                var c = Qt.color("#" + clean);
                                if (c.hslHue >= 0) {
                                    /* QML color hslHue is 0-359, hslSaturation 0-255;
                                     * the strip stores hue 0-359 and sat 0-1. */
                                    Flags.manualHue = Math.round(c.hslHue);
                                    Flags.manualSat = c.hslSaturation / 255;
                                } else {
                                    Flags.manualSat = 0;
                                }
                                root.applyManual();
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()
                    }

                    Rectangle {
                        anchors.left: hexField.left
                        anchors.right: hexField.right
                        anchors.top: hexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: hexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }

        SettingsRow {
            id: dockGlassRow
            surface: root
            name: "Dock glass"
            icon: "droplet"
            visible: Flags.dockEnabled

            SettingsSeg {
                s: root.s
                options: [{ label: "Transparent", value: "transparent" }, { label: "Solid", value: "solid" }]
                value: root.glassShown
                onPicked: (v) => Flags.dockStyle = v
            }
        }

        SettingsRow {
            id: dockMinimalRow
            surface: root
            name: "Minimal dock"
            icon: "dot"
            visible: Flags.dockEnabled
            last: Flags.dockEnabled

            LinkToggle {
                s: root.s
                on: Flags.dockMinimal
                onToggled: Flags.dockMinimal = !Flags.dockMinimal
            }
        }
    }
}