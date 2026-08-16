pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 色 THEME sub-surface: the theme switch (light or dark pill, dynamic
 * per-wallpaper, or a manually chosen hue) with the manual hue editor that
 * unfolds beneath it, and the wallpaper folder that feeds the rotation.
 * Reached from the Appearance index and folds back to it on the back chevron
 * or an empty click.
 *
 * Manual palette mode reveals a rainbow hue strip and a dark/light choice; moving
 * either rebuilds the rice colour set from that hue through wallcolors.py --hue
 * and reloads Hyprland and the terminal, debounced so a drag does not spawn a
 * build per pixel.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    /** Current theme key; legacy "static" reads as the dark pill. */
    readonly property string themeMode: Flags.paletteMode === "static" ? "dark" : Flags.paletteMode

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
        Flags.paletteMode = v;
        if (v === "manual")
            applyManual();
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
            "wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; python3 \"$wallscript\" --hue \"$1\" \"$2\" \"$3\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    Process {
        id: dynamicProc
        command: ["sh", "-c",
            "f=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper\"; pic=$(cat \"$f\" 2>/dev/null); case \"$pic\" in *.[Mm][Pp]4|*.[Ww][Ee][Bb][Mm]|*.[Mm][Kk][Vv]|*.[Mm][Oo][Vv]) pic=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima-wallpaper-still.png\";; esac; wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; [ -f \"$pic\" ] && python3 \"$wallscript\" \"$pic\" >/dev/null 2>&1; hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1 || true"]
    }

    Connections {
        target: Flags
        function onManualHueChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
        function onManualSatChanged() {
            if (Flags.paletteMode === "manual")
                root.applyManual();
        }
    }

    rows: [
        { item: paletteRow, kind: "seg", vals: ["light", "dark", "dynamic", "manual"], get: function () { return root.themeMode; }, set: function (v) { root.applyMode(v); } },
        { item: wpDirRow, kind: "text", activate: function () {
            wpDirRow.editing = !wpDirRow.editing;
            if (wpDirRow.editing) {
                wpDirField.text = Flags.wallpaperDir;
                Qt.callLater(wpDirField.forceActiveFocus);
            }
        } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "色"
            title: "THEME"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: paletteRow
            surface: root
            name: "Theme"
            icon: "palette"

            SettingsSeg {
                s: root.s
                options: [{ label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: root.themeMode
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, folded shut unless the palette is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. The strip is mouse-driven and
         * stays out of the keyboard row registry.
         */
        Item {
            id: manualSection
            width: parent.width
            height: Flags.paletteMode === "manual" ? manualCol.implicitHeight : 0
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
                                    Flags.manualHue = Math.round(c.hslHue * 359);
                                    Flags.manualSat = c.hslSaturation;
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
            id: wpDirRow
            surface: root
            name: "Wallpaper folder"
            icon: "wallpaper"
            sub: wpDirRow.editing ? "Return to save · Esc to cancel" : Walls.wpDir
            captionOnFocus: true
            last: true

            property bool editing: false

            Item {
                width: wpDirRow.editing ? 200 * root.s : 26 * root.s
                height: 26 * root.s
                Behavior on width { NumberAnimation { duration: Motion.fast } }

                Rectangle {
                    anchors.fill: parent
                    radius: 9 * root.s
                    visible: wpDirRow.editing
                    color: Qt.alpha(Theme.frameBg, 0.7)
                    border.width: 1
                    border.color: wpDirField.activeFocus ? Qt.alpha(Theme.vermLit, 0.7) : Theme.hairSoft
                }

                TextInput {
                    id: wpDirField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    visible: wpDirRow.editing
                    clip: true
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    selectByMouse: true
                    selectionColor: Theme.verm

                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            Flags.wallpaperDir = text.trim();
                            Walls.refresh();
                            wpDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape) {
                            wpDirRow.editing = false;
                            focus = false;
                            e.accepted = true;
                        }
                    }
                }

                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !wpDirRow.editing
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "wallpaper"
                    color: wpDirRow.focused ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
            }
        }
    }
}
