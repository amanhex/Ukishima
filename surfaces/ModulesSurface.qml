pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 器 TOGGLE MODULES sub-surface: which optional items the expanded pill's hover
 * row draws. Everything core always draws — the workspaces, the
 * wifi/bluetooth/battery cluster, the clock, weather, notifications, mixer and
 * clipboard — so these switches hide the rest.
 *
 * The Appearance cog is deliberately absent: it is the only way into settings,
 * and a switch that hides the only door back to itself is the one-way door the
 * dock row on the DISPLAY surface warns about. Reached from DISPLAY and folds
 * back to it on the back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "display"
    implicitHeight: content.implicitHeight

    rows: [
        { item: sysmonRow, kind: "toggle", get: function () { return Flags.pillShowSysmon; }, set: function (v) { Flags.pillShowSysmon = v; } },
        { item: recRow, kind: "toggle", get: function () { return Flags.pillShowRecorder; }, set: function (v) { Flags.pillShowRecorder = v; } },
        { item: wallRow, kind: "toggle", get: function () { return Flags.pillShowWallpaper; }, set: function (v) { Flags.pillShowWallpaper = v; } },
        { item: scratchRow, kind: "toggle", get: function () { return Flags.pillShowScratch; }, set: function (v) { Flags.pillShowScratch = v; } },
        { item: launchRow, kind: "toggle", get: function () { return Flags.pillShowLauncher; }, set: function (v) { Flags.pillShowLauncher = v; } },
        { item: powerRow, kind: "toggle", get: function () { return Flags.pillShowPower; }, set: function (v) { Flags.pillShowPower = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "器"
            title: "TOGGLE MODULES"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: sysmonRow
            surface: root
            name: "System monitor"
            icon: "monitor"

            LinkToggle {
                s: root.s
                on: Flags.pillShowSysmon
                onToggled: Flags.pillShowSysmon = !Flags.pillShowSysmon
            }
        }

        SettingsRow {
            id: recRow
            surface: root
            name: "Recorder"
            icon: "video"

            LinkToggle {
                s: root.s
                on: Flags.pillShowRecorder
                onToggled: Flags.pillShowRecorder = !Flags.pillShowRecorder
            }
        }

        SettingsRow {
            id: wallRow
            surface: root
            name: "Wallpaper"
            icon: "wallpaper"

            LinkToggle {
                s: root.s
                on: Flags.pillShowWallpaper
                onToggled: Flags.pillShowWallpaper = !Flags.pillShowWallpaper
            }
        }

        SettingsRow {
            id: scratchRow
            surface: root
            name: "Scratchpad"
            icon: "type"

            LinkToggle {
                s: root.s
                on: Flags.pillShowScratch
                onToggled: Flags.pillShowScratch = !Flags.pillShowScratch
            }
        }

        SettingsRow {
            id: launchRow
            surface: root
            name: "Launcher"
            icon: "app-window"

            LinkToggle {
                s: root.s
                on: Flags.pillShowLauncher
                onToggled: Flags.pillShowLauncher = !Flags.pillShowLauncher
            }
        }

        SettingsRow {
            id: powerRow
            surface: root
            name: "Power"
            icon: "shutdown"
            last: true

            LinkToggle {
                s: root.s
                on: Flags.pillShowPower
                onToggled: Flags.pillShowPower = !Flags.pillShowPower
            }
        }
    }
}