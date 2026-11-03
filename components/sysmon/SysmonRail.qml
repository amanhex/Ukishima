pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Rail": a slim console strip. A header line, one level bar per dial,
 * a stat strip, and the speed test at the foot. `host` is SysmonSurface.
 */
Item {
    id: rail

    property var host: null
    readonly property real s: rail.host ? rail.host.s : 1
    /** The surface's own margins are the outer padding; designs add none. */
    readonly property real pad: 0
    readonly property color accent: Theme.vermLit
    readonly property color line: Theme.border

    implicitHeight: body.implicitHeight + 2 * rail.pad

    Column {
        id: body
        anchors.top: parent.top
        anchors.topMargin: rail.pad
        anchors.left: parent.left
        anchors.leftMargin: rail.pad
        anchors.right: parent.right
        anchors.rightMargin: rail.pad
        spacing: 0

        SysmonHeader {
            id: header
            width: parent.width
            host: rail.host
        }

        Item { width: 1; height: 5 * rail.s }

        Rectangle {
            width: parent.width
            height: 1
            color: rail.line
        }

        Item { width: 1; height: 9 * rail.s }

        Column {
            width: parent.width
            spacing: 9 * rail.s

            Repeater {
                model: Sysmon.dialKeys

                delegate: Item {
                    id: dialRow
                    required property int index
                    required property var modelData
                    readonly property string key: modelData
                    readonly property real value: Sysmon.dialValue(key)

                    width: body.width
                    height: 30 * rail.s

                    Text {
                        anchors.left: parent.left
                        text: dialRow.key.toUpperCase()
                        color: Theme.subtle
                        font.family: Theme.fontMono
                        font.pixelSize: 8.5 * rail.s
                        font.letterSpacing: 0.8
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.topMargin: 10 * rail.s
                        visible: dialRow.key !== "mem"
                        text: dialRow.key === "cpu" || dialRow.key === "gpu" ? Sysmon.dialSub(dialRow.key) : ""
                        color: Theme.faint
                        font.family: Theme.fontMono
                        font.pixelSize: 7.5 * rail.s
                    }
                    Text {
                        anchors.right: parent.right
                        text: dialRow.key === "mem"
                            ? Sysmon.dialBig(dialRow.key) + " " + Sysmon.dialSub(dialRow.key)
                            : Sysmon.dialBig(dialRow.key) + Sysmon.dialUnit(dialRow.key)
                        color: Theme.cream
                        font.family: Theme.fontMono
                        font.pixelSize: 15 * rail.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    SysmonMeter {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        host: rail.host
                        value: dialRow.value
                        accent: rail.accent
                        ruler: true
                    }
                }
            }
        }

        Item { width: 1; height: 10 * rail.s }

        Rectangle {
            width: parent.width
            height: 1
            color: rail.line
        }

        Item { width: 1; height: 9 * rail.s }

        Row {
            id: statRow
            width: parent.width

            Repeater {
                model: Sysmon.cellKeys

                delegate: Item {
                    id: stat
                    required property int index
                    required property var modelData
                    readonly property string key: modelData

                    width: statRow.width / Sysmon.cellKeys.length
                    height: 28 * rail.s

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * rail.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Sysmon.statLabel(stat.key).toUpperCase()
                            color: Theme.faint
                            font.family: Theme.fontMono
                            font.pixelSize: 7.5 * rail.s
                            font.letterSpacing: 0.6
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5 * rail.s
                            visible: stat.key === "net"

                            Text {
                                text: "↓" + Sysmon.netDown.toFixed(1)
                                color: Theme.cream
                                font.family: Theme.fontMono
                                font.pixelSize: 11 * rail.s
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: "↑" + Sysmon.netUp.toFixed(1)
                                color: rail.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 11 * rail.s
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: stat.key !== "net"
                            text: Sysmon.statValue(stat.key)
                            color: Theme.cream
                            font.family: Theme.fontMono
                            font.pixelSize: 11 * rail.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 9 * rail.s }

        Rectangle {
            width: parent.width
            height: 1
            color: rail.line
        }

        Item { width: 1; height: 9 * rail.s }

        SysmonSpeed {
            width: parent.width
            host: rail.host
        }
    }

    readonly property point soulPoint: header.mapToItem(rail, header.soulPoint.x, header.soulPoint.y)
}
