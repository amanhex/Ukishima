pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 色 THEME sub-surface: the palette identity — the theme switch (light or dark
 * pill, dynamic per-wallpaper, or a manually chosen hue) with the manual hue
 * editor that unfolds beneath it, and the wallpaper folder that feeds the
 * rotation. The accent override moved to its own 彩 ACCENT sub-surface and the
 * transparency / copy-contrast toggles to 玻 GLASS, so each concern keeps its
 * own column. Reached from the Appearance index and folds back to it on the
 * back chevron or an empty click.
 *
 * Manual palette mode reveals a rainbow hue strip and a dark/light choice; moving
 * either recolours the pill immediately (PaletteHue computes the ramp locally in
 * QML) and rebuilds the rice colour set from that hue through wallcolors.py --hue
 * (terminal, Hyprland, fastfetch), debounced so a drag does not spawn a build per
 * pixel. The rice run never rewrites the shared colors.json, so the dock keeps
 * its own palette while the pill slider moves.
 */
SettingsSurface {
    id: root

    backSurface: "appcat"
    implicitHeight: content.implicitHeight

    property string hueArg: String(Math.round(Flags.manualHue))
    property string modeArg: Flags.manualDark ? "dark" : "light"
    property string satArg: String(Flags.manualSat)

    /** Current theme key; legacy "static" reads as the dark pill. */
    readonly property string themeMode: Flags.paletteMode === "static" ? "dark" : Flags.paletteMode

    readonly property color accentColor: Qt.hsla(Flags.manualHue / 360, Flags.manualSat, Flags.manualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: Theme.hexUpper(accentColor)

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
            paletteRegen.running = true;
        // Dynamic reads colors.json (Dyn) for the wallpaper palette. Entering it
        // refreshes that file from the current wallpaper (wallpaper.sh regen) so a
        // stale cache — e.g. left by an older install that stored the manual hue
        // in colors.json — never shows the wrong scheme.
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
            "wallscript=\"" + Config.hyprPath("scripts", "wallcolors.py") + "\"; python3 \"$wallscript\" --hue \"$1\" \"$2\" \"$3\" && hyprctl reload >/dev/null 2>&1; busctl --user call com.mitchellh.ghostty /com/mitchellh/ghostty org.gtk.Actions Activate \"sava{sv}\" reload-config 0 0 >/dev/null 2>&1; command -v kitty >/dev/null 2>&1 && timeout -k 1 5 kitty @ set-colors \"${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/kitty-colors\" >/dev/null 2>&1 || true",
            "sh", root.hueArg, root.modeArg, root.satArg]
    }

    /** Refresh the shared wallpaper palette from the current wallpaper when
     *  dynamic is picked — everything writes only into the ukishima cache dir. */
    Process {
        id: paletteRegen
        command: ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "regen"]
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

Item { width: 1; height: 10 * root.s }
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

                HueStrip {
                    s: root.s
                    hue: Flags.manualHue
                    sat: Flags.manualSat
                    thumbColor: root.accentColor
                    thumbBorder: Theme.cream
                    onSatSeeded: Flags.manualSat = 0.5
                    onHuePicked: (h) => Flags.manualHue = h
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

                HexField {
                    s: root.s
                    placeholder: root.currentHex
                    ink: Theme.cream
                    faint: Theme.faint
                    accent: Theme.verm
                    onCommitted: (hue, sat) => {
                        if (hue >= 0) {
                            Flags.manualHue = hue;
                            Flags.manualSat = sat;
                        } else {
                            Flags.manualSat = 0;
                        }
                        root.applyManual();
                    }
                }
            }
        }

        SettingsRow {
            id: wpDirRow
            surface: root
            name: "Wallpaper folder"
            icon: "wallpaper"
            //* Cleared while the field is open — the wallpaper surface's
            //* header path has no caption beside its field either, and a
            //* wrapping sub re-laid out at a width near zero would spike the
            //* row height. The path comes back with it on Return/Esc.
            sub: wpDirRow.editing ? "" : Walls.wpDir
            captionOnFocus: true
            last: true

            property bool editing: false

            //* Wallpaper-surface style field (see Wallpaper.qml folderRow):
            //* a bare TextInput, no box, opening instantly at full row width.
            //* 58* is where the name's text column ends — its 44* left offset
            //* plus its 14* gap — so the name elides to nothing as the field
            //* claims the space instead of sitting under it. No width
            //* animation: the swap is instant on the wallpaper surface too,
            //* and an animated close would re-wrap the caption mid-move.
            Item {
                width: wpDirRow.editing ? wpDirRow.width - 58 * root.s : 26 * root.s
                height: 26 * root.s

                TextInput {
                    id: wpDirField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wpDirRow.editing
                    enabled: wpDirRow.editing
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

                    //* The resolved dir as the hint while the flag is empty —
                    //* the same placeholder the wallpaper surface's field
                    //* shows for the same flag.
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: wpDirField.text.length === 0
                        text: Walls.wpDir
                        elide: Text.ElideMiddle
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
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