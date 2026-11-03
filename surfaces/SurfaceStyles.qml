pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 枠 SURFACE STYLES: list of surfaces and their available UI variants.
 * Users can choose different visual styles for each surface from here.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    rows: [
        { item: mediaStyleRow, kind: "seg", vals: ["default", "rail", "sleeve", "ledger", "matrix", "title"], get: function () { return Flags.styleMedia; }, set: function (v) { Flags.styleMedia = v; } },
        { item: mixerStyleRow, kind: "seg", vals: ["default", "comb", "slats", "stipple", "weave"], get: function () { return Flags.styleMixer; }, set: function (v) { Flags.styleMixer = v; } },
        { item: sysmonStyleRow, kind: "seg", vals: ["default", "rail", "ledger", "matrix", "title"], get: function () { return Flags.styleSysmon; }, set: function (v) { Flags.styleSysmon = v; } },
        { item: scratchStyleRow, kind: "seg", vals: ["default", "cassette", "index", "console", "ash"], get: function () { return Flags.styleScratch; }, set: function (v) { Flags.styleScratch = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "枠"
            title: "SURFACE STYLES"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }

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
            last: true

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
    }
}