pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Ledger": a ruled table. Every dial and stat becomes a numbered row
 * with its level bar and value, so the whole machine reads as one ledger page.
 * `host` is SysmonSurface.
 */
Item {
    id: ledger

    property var host: null
    readonly property real s: ledger.host ? ledger.host.s : 1
    /** The surface's own margins are the outer padding; designs add none. */
    readonly property real pad: 0
    readonly property color accent: Theme.vermLit
    readonly property color line: Theme.border
    readonly property var rows: Sysmon.dialKeys.concat(Sysmon.cellKeys)

    implicitHeight: body.implicitHeight + 2 * ledger.pad

    Column {
        id: body
        anchors.top: parent.top
        anchors.topMargin: ledger.pad
        anchors.left: parent.left
        anchors.leftMargin: ledger.pad
        anchors.right: parent.right
        anchors.rightMargin: ledger.pad
        spacing: 0

        SysmonHeader {
            id: header
            width: parent.width
            wordmark: "SYSTEM LEDGER"
            host: ledger.host
        }

        Item { width: 1; height: 5 * ledger.s }

        Rectangle {
            width: parent.width
            height: 1
            color: ledger.line
        }

        Item { width: 1; height: 6 * ledger.s }

        Repeater {
            model: ledger.rows

            delegate: Item {
                id: row
                required property int index
                required property var modelData
                readonly property string key: modelData
                readonly property bool isDial: Sysmon.dialKeys.indexOf(key) >= 0
                readonly property real pct: isDial ? Sysmon.dialValue(key) : Sysmon.statPct(key)

                width: body.width
                height: 26 * ledger.s

                Text {
                    id: idx
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.index + 1).padStart(2, "0")
                    color: Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 7.5 * ledger.s
                    font.features: { "tnum": 1 }
                }

                Text {
                    id: name
                    anchors.left: idx.right
                    anchors.leftMargin: 8 * ledger.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 50 * ledger.s
                    text: row.key.toUpperCase()
                    color: Theme.subtle
                    font.family: Theme.fontMono
                    font.pixelSize: 8.5 * ledger.s
                    font.letterSpacing: 0.7
                }

                Text {
                    id: note
                    anchors.left: name.right
                    anchors.leftMargin: 4 * ledger.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.key === "cpu" || row.key === "gpu" ? Sysmon.dialSub(row.key) : ""
                    color: Theme.faint
                    font.family: Theme.fontMono
                    font.pixelSize: 7.5 * ledger.s
                }

                SysmonMeter {
                    anchors.left: note.right
                    anchors.leftMargin: 6 * ledger.s
                    anchors.right: value.left
                    anchors.rightMargin: 8 * ledger.s
                    anchors.verticalCenter: parent.verticalCenter
                    host: ledger.host
                    value: row.pct
                    accent: ledger.accent
                }

                Text {
                    id: value
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.key === "net"
                        ? "↓" + Sysmon.netDown.toFixed(1) + "  ↑" + Sysmon.netUp.toFixed(1)
                        : row.isDial
                            ? (row.key === "mem"
                                ? Sysmon.dialBig(row.key) + " " + Sysmon.dialSub(row.key)
                                : Sysmon.dialBig(row.key) + Sysmon.dialUnit(row.key))
                            : Sysmon.statValue(row.key)
                    color: Theme.cream
                    font.family: Theme.fontMono
                    font.pixelSize: 10 * ledger.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.hairSoft
                }
            }
        }

        Item { width: 1; height: 8 * ledger.s }

        SysmonSpeed {
            width: parent.width
            host: ledger.host
        }
    }

    readonly property point soulPoint: header.mapToItem(ledger, header.soulPoint.x, header.soulPoint.y)
}
