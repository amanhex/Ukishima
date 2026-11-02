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
        { item: mediaStyleRow, kind: "seg", vals: ["default", "rail", "sleeve", "ledger", "matrix", "title"], get: function () { return Flags.styleMedia; }, set: function (v) { Flags.styleMedia = v; } }
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
            last: true

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
    }
}