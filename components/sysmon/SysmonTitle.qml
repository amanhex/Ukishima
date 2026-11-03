pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea "Title": typography leads. CPU is the hero readout, the other dials
 * sit as a secondary row, and the stat strip and speed test share the foot.
 * `host` is SysmonSurface.
 */
Item {
    id: titleStyle

    property var host: null
    readonly property real s: titleStyle.host ? titleStyle.host.s : 1
    /** The surface's own margins are the outer padding; designs add none. */
    readonly property real pad: 0
    readonly property color accent: Theme.vermLit
    readonly property color line: Theme.border
    readonly property var secondary: Sysmon.dialKeys.filter(function (k) { return k !== "cpu"; })

    implicitHeight: body.implicitHeight + 2 * titleStyle.pad

    Column {
        id: body
        anchors.top: parent.top
        anchors.topMargin: titleStyle.pad
        anchors.left: parent.left
        anchors.leftMargin: titleStyle.pad
        anchors.right: parent.right
        anchors.rightMargin: titleStyle.pad
        spacing: 0

        SysmonHeader {
            id: header
            width: parent.width
            wordmark: "SYSTEM // VITALS"
            host: titleStyle.host
        }

        Item { width: 1; height: 4 * titleStyle.s }

        Rectangle {
            width: parent.width
            height: 1
            color: titleStyle.line
        }

        Item { width: 1; height: 8 * titleStyle.s }

        Item {
            id: hero
            width: parent.width
            height: 72 * titleStyle.s

            Text {
                anchors.left: parent.left
                text: "CPU LOAD"
                color: titleStyle.accent
                font.family: Theme.fontMono
                font.pixelSize: 8.5 * titleStyle.s
                font.letterSpacing: 1
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 12 * titleStyle.s
                id: bigCpu
                text: Sysmon.cpu + "%"
                color: Theme.cream
                font.family: Theme.fontMono
                font.pixelSize: 38 * titleStyle.s
                font.weight: Font.DemiBold
                font.letterSpacing: -1 * titleStyle.s
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.right: parent.right
                anchors.baseline: bigCpu.baseline
                text: Sysmon.cpuTemp >= 0 ? Sysmon.cpuTemp + "°C" : ""
                color: Theme.subtle
                font.family: Theme.fontMono
                font.pixelSize: 11 * titleStyle.s
                font.features: { "tnum": 1 }
            }

            SysmonMeter {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                host: titleStyle.host
                value: Sysmon.cpu
                accent: titleStyle.accent
                ruler: true
            }
        }

        Item { width: 1; height: 12 * titleStyle.s }

        Row {
            id: secondaryRow
            width: parent.width
            spacing: 18 * titleStyle.s

            Repeater {
                model: titleStyle.secondary

                delegate: Item {
                    id: secondary
                    required property int index
                    required property var modelData
                    readonly property string key: modelData

                    width: (secondaryRow.width - secondaryRow.spacing * (titleStyle.secondary.length - 1))
                        / Math.max(1, titleStyle.secondary.length)
                    height: 40 * titleStyle.s

                    Text {
                        anchors.left: parent.left
                        text: secondary.key.toUpperCase()
                        color: Theme.subtle
                        font.family: Theme.fontMono
                        font.pixelSize: 8 * titleStyle.s
                        font.letterSpacing: 0.8
                    }

                    Text {
                        anchors.right: parent.right
                        text: secondary.key === "mem"
                            ? Sysmon.dialBig(secondary.key) + " " + Sysmon.dialSub(secondary.key)
                            : Sysmon.dialBig(secondary.key) + Sysmon.dialUnit(secondary.key)
                        color: Theme.cream
                        font.family: Theme.fontMono
                        font.pixelSize: 16 * titleStyle.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }

                    SysmonMeter {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        host: titleStyle.host
                        value: Sysmon.dialValue(secondary.key)
                        accent: titleStyle.accent
                    }
                }
            }
        }

        Item { width: 1; height: 12 * titleStyle.s }

        Rectangle {
            width: parent.width
            height: 1
            color: titleStyle.line
        }

        Item { width: 1; height: 9 * titleStyle.s }

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
                    height: 26 * titleStyle.s

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * titleStyle.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Sysmon.statLabel(stat.key).toUpperCase()
                            color: Theme.faint
                            font.family: Theme.fontMono
                            font.pixelSize: 7.5 * titleStyle.s
                            font.letterSpacing: 0.6
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5 * titleStyle.s
                            visible: stat.key === "net"

                            Text {
                                text: "↓" + Sysmon.netDown.toFixed(1)
                                color: Theme.cream
                                font.family: Theme.fontMono
                                font.pixelSize: 11 * titleStyle.s
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                text: "↑" + Sysmon.netUp.toFixed(1)
                                color: titleStyle.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 11 * titleStyle.s
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
                            font.pixelSize: 11 * titleStyle.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 8 * titleStyle.s }

        SysmonSpeed {
            width: parent.width
            host: titleStyle.host
        }
    }

    readonly property point soulPoint: header.mapToItem(titleStyle, header.soulPoint.x, header.soulPoint.y)
}
