pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Matrix": every reading becomes a bordered cell with a segmented
 * level bar, laid out two-up like a hardware panel. `host` is SysmonSurface.
 */
Item {
    id: matrix

    property var host: null
    readonly property real s: matrix.host ? matrix.host.s : 1
    /** The surface's own margins are the outer padding; designs add none. */
    readonly property real pad: 0
    readonly property color accent: Theme.vermLit
    readonly property color line: Theme.border
    readonly property var rows: Sysmon.dialKeys.concat(Sysmon.cellKeys)

    implicitHeight: body.implicitHeight + 2 * matrix.pad

    Column {
        id: body
        anchors.top: parent.top
        anchors.topMargin: matrix.pad
        anchors.left: parent.left
        anchors.leftMargin: matrix.pad
        anchors.right: parent.right
        anchors.rightMargin: matrix.pad
        spacing: 0

        SysmonHeader {
            id: header
            width: parent.width
            wordmark: "NR-2B // SYSTEM"
            host: matrix.host
        }

        Item { width: 1; height: 5 * matrix.s }

        Rectangle {
            width: parent.width
            height: 1
            color: matrix.line
        }

        Item { width: 1; height: 9 * matrix.s }

        Grid {
            id: grid
            width: parent.width
            columns: 2
            columnSpacing: 8 * matrix.s
            rowSpacing: 8 * matrix.s

            Repeater {
                model: matrix.rows

                delegate: Item {
                    id: tile
                    required property int index
                    required property var modelData
                    readonly property string key: modelData
                    readonly property bool isDial: Sysmon.dialKeys.indexOf(key) >= 0
                    readonly property real pct: isDial ? Sysmon.dialValue(key) : Sysmon.statPct(key)

                    width: (grid.width - grid.columnSpacing) / 2
                    height: 54 * matrix.s

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.cardBot
                        border.width: 1
                        border.color: Theme.border
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * matrix.s
                        anchors.top: parent.top
                        anchors.topMargin: 7 * matrix.s
                        text: tile.key.toUpperCase()
                        color: Theme.faint
                        font.family: Theme.fontMono
                        font.pixelSize: 7.5 * matrix.s
                        font.letterSpacing: 0.7
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * matrix.s
                        anchors.top: parent.top
                        anchors.topMargin: 5 * matrix.s
                        text: tile.key === "cpu" || tile.key === "gpu" ? Sysmon.dialSub(tile.key) : ""
                        color: Theme.faint
                        font.family: Theme.fontMono
                        font.pixelSize: 7.5 * matrix.s
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * matrix.s
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * matrix.s
                        anchors.top: parent.top
                        anchors.topMargin: 20 * matrix.s
                        text: tile.key === "net"
                            ? "↓" + Sysmon.netDown.toFixed(1) + "  ↑" + Sysmon.netUp.toFixed(1)
                            : tile.isDial
                                ? (tile.key === "mem"
                                    ? Sysmon.dialBig(tile.key) + " " + Sysmon.dialSub(tile.key)
                                    : Sysmon.dialBig(tile.key) + Sysmon.dialUnit(tile.key))
                                : Sysmon.statValue(tile.key)
                        color: Theme.cream
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: 15 * matrix.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    SysmonMeter {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * matrix.s
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * matrix.s
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8 * matrix.s
                        host: matrix.host
                        value: tile.pct
                        accent: matrix.accent
                        segments: 12
                    }
                }
            }
        }

        Item { width: 1; height: 9 * matrix.s }

        SysmonSpeed {
            width: parent.width
            host: matrix.host
        }
    }

    readonly property point soulPoint: header.mapToItem(matrix, header.soulPoint.x, header.soulPoint.y)
}
