pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"
import "../lib/fuzzy.js" as Fuzzy

/**
 * 相 DOCK APPEARANCE: theme, OLED, glass, manual hue editor.
 * Reached from DOCK SETTINGS and folds back on the back chevron.
 */
DockPanel {
    id: root

    backSurface: "dockSettings"
    implicitHeight: content.implicitHeight

    /** Current theme key; legacy "auto"/"transparent" saves read as dark. */
    readonly property string themeShown: (Flags.dockTheme === "auto"
        || Flags.dockTheme === "transparent") ? "dark" : Flags.dockTheme

    /** The dock's manual hue editor drives the dock's OWN flags only
     * (dockManualHue/dockManualSat/dockManualDark) — a live swatch for the
     * local PaletteHue render in DockBar. */
    readonly property color accentColor: Qt.hsla(Flags.dockManualHue / 360, Flags.dockManualSat, Flags.dockManualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: Theme.hexUpper(accentColor)

    /** Glass depth label. */
    readonly property string glassShown: Flags.dockStyle === "solid" ? "solid" : "transparent"

    rows: {
        var base = [
            { item: themeRow, kind: "seg", vals: ["light", "dark", "dynamic", "manual"], get: function () { return root.themeShown; }, set: function (v) { root.applyMode(v); } }
        ];
        // OLED only lives on Dark; it joins the list only while it is on
        // screen, so the keyboard cursor can never land on the hidden row.
        if (root.themeShown === "dark")
            base.push({ item: oledRow, kind: "toggle", get: function () { return Flags.dockOled; }, set: function (v) { Flags.dockOled = v; } });
        base.push(
            { item: glassRow, kind: "seg", vals: ["transparent", "solid"], get: function () { return root.glassShown; }, set: function (v) { Flags.dockStyle = v; } }
        );
        // Manual hue editor only on Manual theme and not OLED.
        if (Flags.dockTheme === "manual" && !Flags.dockOled)
            base.push({ item: manualSection, kind: "raw" });
        return base;
    }

    /** Switching the dock theme only sets the flag; the dock re-resolves its own
     * palette locally (PaletteHue for manual, Dyn for dynamic, static hexes for
     * light/dark). No wallcolors process, no colors.json write — the pill never
     * notices. Picking dynamic refreshes the shared colors.json from the current
     * wallpaper first, so the dock's dynamic palette is never a stale cache. */
    function applyMode(v) {
        Flags.dockTheme = v;
        // OLED only lives on Dark; leaving dark switches it off so the hidden
        // toggle can never leave an invisible mode latched on behind the theme.
        if (v !== "dark")
            Flags.dockOled = false;
        if (v === "dynamic")
            paletteRegen.running = true;
    }

    /** Refresh the shared wallpaper palette (used by both dynamic sides) from the
     * current wallpaper; everything writes only into the ukishima cache dir. */
    Process {
        id: paletteRegen
        command: ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "regen"]
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            pal: root.pal
            glyph: "相"
            title: "APPEARANCE"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: themeRow
            surface: root
            name: "Dock theme"
            icon: "palette"

            Dropdown {
                id: themeDrop
                s: root.s
                pal: root.pal
                options: [{ label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: root.themeShown
                onChipClicked: themeDrop.open = !themeDrop.open
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Pure-black variant of Dark, separate from the theme picker: surfaces
         * zero to #000000 with light copy. Only exists on Dark — visible here
         * and off whenever the theme moves away. The dock's own toggle — it
         * never touches the pill's.
         */
        SettingsRow {
            id: oledRow
            surface: root
            name: "OLED"
            icon: "moon"
            visible: root.themeShown === "dark"

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockOled
                onToggled: Flags.dockOled = !Flags.dockOled
            }
        }

        SettingsRow {
            id: glassRow
            surface: root
            name: "Dock glass"
            icon: "droplet"

            Dropdown {
                id: glassDrop
                s: root.s
                pal: root.pal
                options: [{ label: "Transparent", value: "transparent" }, { label: "Solid", value: "solid" }]
                value: root.glassShown
                onChipClicked: glassDrop.open = !glassDrop.open
                onPicked: (v) => Flags.dockStyle = v
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
            height: manualCol.implicitHeight
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4 * root.s
                anchors.rightMargin: 4 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                HueStrip {
                    s: root.s
                    hue: Flags.dockManualHue
                    sat: Flags.dockManualSat
                    thumbColor: root.accentColor
                    thumbBorder: root.pal ? root.pal.ink : "white"
                    onSatSeeded: Flags.dockManualSat = 0.5
                    onHuePicked: (h) => Flags.dockManualHue = h
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
                        border.color: root.pal ? root.pal.edge : "gray"
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
                            color: root.pal ? root.pal.ink : "white"
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.dockManualDark ? "dark" : "light")
                            color: root.pal ? root.pal.faint : "gray"
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
                        pal: root.pal
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.dockManualDark
                        onPicked: (v) => { Flags.dockManualDark = v; }
                    }
                }

                HexField {
                    s: root.s
                    placeholder: root.currentHex
                    ink: root.pal ? root.pal.ink : "white"
                    faint: root.pal ? root.pal.faint : "gray"
                    accent: root.pal ? root.pal.accent : "gray"
                    onCommitted: (hue, sat) => {
                        if (hue >= 0) {
                            Flags.dockManualHue = hue;
                            Flags.dockManualSat = sat;
                        } else {
                            Flags.dockManualSat = 0;
                        }
                    }
                }
            }
        }
    }
}