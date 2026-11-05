pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 枠 SURFACE STYLES: the per-surface variant pickers, reached from the
 * APPEARANCE page. Each row picks the visual style of one surface — the resting
 * pill face, the media player, the mixer, the system monitor, the scratchpad and
 * the session lock — and writes it straight to `Flags`. Folds back to APPEARANCE
 * on the back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appcat"

    rows: [
        { item: pillRow, kind: "seg", vals: ["minimal", "classic", "system", "status", "strip"], get: function () { return Flags.mainDisplay; }, set: function (v) { Flags.mainDisplay = v; } },
        { item: mediaStyleRow, kind: "seg", vals: ["default", "rail", "sleeve", "ledger", "matrix", "title"], get: function () { return Flags.styleMedia; }, set: function (v) { Flags.styleMedia = v; } },
        { item: mixerStyleRow, kind: "seg", vals: ["default", "comb", "slats", "stipple", "weave"], get: function () { return Flags.styleMixer; }, set: function (v) { Flags.styleMixer = v; } },
        { item: sysmonStyleRow, kind: "seg", vals: ["default", "rail", "ledger", "matrix", "title"], get: function () { return Flags.styleSysmon; }, set: function (v) { Flags.styleSysmon = v; } },
        { item: scratchStyleRow, kind: "seg", vals: ["default", "cassette", "index", "console", "ash"], get: function () { return Flags.styleScratch; }, set: function (v) { Flags.styleScratch = v; } },
        { item: lockStyleRow, kind: "seg", vals: ["default", "relay", "folio", "editorial", "phase", "spine", "reactive"], get: function () { return Flags.styleLock; }, set: function (v) { Flags.styleLock = v; } }
    ]

    glyph: "枠"
    title: "SURFACE STYLES"
    showBack: true

    SettingsRow {
        id: pillRow
        surface: root
        glyph: "時"
        name: "Pill display"

        Dropdown {
            id: pillDrop
            s: root.s
            options: [
                { label: "Minimal", value: "minimal" },
                { label: "Classic", value: "classic" },
                { label: "System", value: "system" },
                { label: "Status", value: "status" },
                { label: "Strip", value: "strip" }
            ]
            value: Flags.mainDisplay
            onChipClicked: pillDrop.open = !pillDrop.open
            onPicked: (v) => {
                Flags.mainDisplay = v
            }
        }
    }

    SettingsRow {
        id: mediaStyleRow
        surface: root
        glyph: "媒"
        name: "Media Player"

        Dropdown {
            id: mediaStyleDrop
            s: root.s
            options: [
                { label: "Default", value: "default" },
                { label: "Rail", value: "rail" },
                { label: "Sleeve", value: "sleeve" },
                { label: "Ledger", value: "ledger" },
                { label: "Matrix", value: "matrix" },
                { label: "Title", value: "title" }
            ]
            value: Flags.styleMedia
            onChipClicked: mediaStyleDrop.open = !mediaStyleDrop.open
            onPicked: (v) => {
                Flags.styleMedia = v
            }
        }
    }

    SettingsRow {
        id: mixerStyleRow
        surface: root
        glyph: "調"
        name: "Mixer"

        Dropdown {
            id: mixerStyleDrop
            s: root.s
            options: [
                { label: "Default", value: "default" },
                { label: "Comb", value: "comb" },
                { label: "Slats", value: "slats" },
                { label: "Stipple", value: "stipple" },
                { label: "Weave", value: "weave" }
            ]
            value: Flags.styleMixer
            onChipClicked: mixerStyleDrop.open = !mixerStyleDrop.open
            onPicked: (v) => {
                Flags.styleMixer = v
            }
        }
    }

    SettingsRow {
        id: sysmonStyleRow
        surface: root
        glyph: "系"
        name: "System Monitor"

        Dropdown {
            id: sysmonStyleDrop
            s: root.s
            options: [
                { label: "Default", value: "default" },
                { label: "Rail", value: "rail" },
                { label: "Ledger", value: "ledger" },
                { label: "Matrix", value: "matrix" },
                { label: "Title", value: "title" }
            ]
            value: Flags.styleSysmon
            onChipClicked: sysmonStyleDrop.open = !sysmonStyleDrop.open
            onPicked: (v) => {
                Flags.styleSysmon = v
            }
        }
    }

    SettingsRow {
        id: scratchStyleRow
        surface: root
        glyph: "記"
        name: "Scratchpad"

        Dropdown {
            id: scratchStyleDrop
            s: root.s
            options: [
                { label: "Default", value: "default" },
                { label: "Cassette", value: "cassette" },
                { label: "Index", value: "index" },
                { label: "Console", value: "console" },
                { label: "Ash", value: "ash" }
            ]
            value: Flags.styleScratch
            onChipClicked: scratchStyleDrop.open = !scratchStyleDrop.open
            onPicked: (v) => {
                Flags.styleScratch = v
            }
        }
    }

    SettingsRow {
        id: lockStyleRow
        surface: root
        glyph: "錠"
        name: "Lock Screen"
        last: true

        Dropdown {
            id: lockStyleDrop
            s: root.s
            options: [
                { label: "Default", value: "default" },
                { label: "Relay", value: "relay" },
                { label: "Folio", value: "folio" },
                { label: "Editorial", value: "editorial" },
                { label: "Phase", value: "phase" },
                { label: "Spine", value: "spine" },
                { label: "Reactive", value: "reactive" }
            ]
            value: Flags.styleLock
            onChipClicked: lockStyleDrop.open = !lockStyleDrop.open
            onPicked: (v) => {
                Flags.styleLock = v
            }
        }
    }

}
