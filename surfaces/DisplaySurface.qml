pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 時 DISPLAY sub-surface: how the pill itself looks and what the clock shows —
 * the resting display mode, the 12/24h format, running seconds, the Japanese
 * header glyphs and the music visualizer — plus the bottom dock's on/off switch.
 * Reached from the Appearance index and folds back to it on the back chevron or
 * an empty click.
 *
 * The expanded pill's module switches keep their own 器 PILL MODULES
 * sub-surface, linked from the `modulesTile` row below, so they do not bury
 * the clock controls; both fold back to DISPLAY on the chevron.
 *
 * The dock's switch is the only dock control here; the rest of the dock's
 * settings are on the dock, in the panel its own gear opens. See `dockRow` for
 * why the switch has to live where the dock cannot reach.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: mainRow, kind: "seg", vals: ["minimal", "classic", "system", "strip"], get: function () { return Flags.mainDisplay; }, set: function (v) { Flags.mainDisplay = v; } },
        { item: expandRow, kind: "seg", vals: ["media", "pill"], get: function () { return Flags.expandTo; }, set: function (v) { Flags.expandTo = v; } },
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: vizRow, kind: "toggle", get: function () { return Flags.musicViz; }, set: function (v) { Flags.musicViz = v; } },
        { item: modulesTile, kind: "nav", surface: "modules" },
        { item: dockRow, kind: "toggle", get: function () { return Flags.dockEnabled; }, set: function (v) { Flags.dockEnabled = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "時"
            title: "DISPLAY"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: mainRow
            surface: root
            name: "Main display"
            icon: "clock"

            SettingsSeg {
                s: root.s
                options: [{ label: "Minimal", value: "minimal" }, { label: "Classic", value: "classic" }, { label: "System", value: "system" }, { label: "Strip", value: "strip" }]
                value: Flags.mainDisplay
                onPicked: (v) => Flags.mainDisplay = v
            }
        }

        SettingsRow {
            id: expandRow
            surface: root
            name: "Media expand"
            icon: "layers"

            SettingsSeg {
                s: root.s
                options: [{ label: "Media", value: "media" }, { label: "Full pill", value: "pill" }]
                value: Flags.expandTo
                onPicked: (v) => Flags.expandTo = v
            }
        }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            icon: "clock"

            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: "Clock seconds"
            icon: "stopwatch"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: glyphRow
            surface: root
            name: "Japanese glyphs"
            icon: "language"

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        /**
         * Only meaningful with the Japanese glyphs off — 時 and the clock face
         * are alternatives in the same slot, so with the glyphs on this toggle
         * changes nothing at all.
         *
         * `visible`, not `enabled`: showGlyphs defaults to on, so an `enabled`
         * row was a live-looking switch that silently did nothing on a fresh
         * install. Hidden, it appears exactly when it has an effect. A disabled
         * item also takes no mouse events, which is what made it read as broken.
         */
        SettingsRow {
            id: clockIconRow
            surface: root
            name: "Clock icon"
            icon: "clock"
            sub: "Icon left of the time"
            visible: !Flags.showGlyphs

            LinkToggle {
                s: root.s
                on: Flags.clockIcon
                onToggled: Flags.clockIcon = !Flags.clockIcon
            }
        }

        SettingsRow {
            id: vizRow
            surface: root
            name: "Music visualizer"
            icon: "music"

            LinkToggle {
                s: root.s
                on: Flags.musicViz
                onToggled: Flags.musicViz = !Flags.musicViz
            }
        }

        /**
         * Which icons the expanded pill's hover row draws keeps its own
         * surface — 器 TOGGLE MODULES, opened by this row — so the optional
         * module switches do not bury the clock settings. See that file for
         * the list and for why the Appearance cog is not among them.
         */
        SettingsRow {
            id: modulesTile
            surface: root
            glyph: "器"
            name: "Toggle modules"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === modulesTile ? Theme.cream : Theme.iconDim
                stroke: 1.9
            }
        }

        /**
         * The air the pill keeps between itself and the windows that tile
         * around it, as a percentage of the shipped 12px: 100% is the shipped
         * gap, 0% tucks the windows flush under the pill — pickable as four
         * fixed steps, like the Interface surface's UI scale row. Hidden
         * under auto-hide: the pill then reserves no band at all, so the gap
         * it would describe does not exist either.
         */
        SettingsRow {
            id: pillGapRow
            surface: root
            name: "Window gap"
            icon: "monitor"
            visible: !Flags.autoHide

            SettingsSeg {
                s: root.s
                options: [{ label: "25%", value: 0.25 }, { label: "50%", value: 0.5 }, { label: "100%", value: 1 }, { label: "150%", value: 1.5 }]
                value: Flags.appGap
                onPicked: (v) => Flags.appGap = v
            }
        }

        /**
         * 泊 The bottom dock's on/off switch — the ONE dock setting the pill
         * keeps, and it is here for a structural reason rather than a tidy one.
         *
         * Everything else the dock can be told lives on the dock itself, in the
         * panel its own gear chip opens. But that panel can only be opened from
         * the gear, and the gear is on the bar, and the bar is what slides off
         * the bottom edge when the dock is disabled. A switch that can switch
         * off the only thing you can reach it through is a one-way door, so this
         * row is the way back — here, in the pill, which is always on screen.
         *
         * It is a switch and not a link into the dock's settings, on purpose:
         * the pill must not become a second front door to a panel that belongs to
         * the dock, or the two would drift apart again. Turning the dock on puts
         * its gear within reach; the gear leads to everything else.
         */
        SettingsRow {
            id: dockRow
            surface: root
            name: "Dock"
            icon: "dock"
            last: true

            LinkToggle {
                s: root.s
                on: Flags.dockEnabled
                onToggled: Flags.dockEnabled = !Flags.dockEnabled
            }
        }
    }
}
