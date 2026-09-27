import QtQuick
import QtQuick.Shapes
import Quickshell.Networking

/**
 * Lockscreen wifi (top-left): the hand-drawn wifi glyph
 * (components/WifiGlyph.qml) ported self-contained — the lockscreen runs
 * as a separate process that cannot import Singletons/, components/ or
 * Theme (singletons are per-process), so colors are baked to white.
 * Keep the paths in sync with WifiGlyph by hand: three arcs + dot in
 * 24x24 space, lit-arc count from signal strength, slash when off.
 */
Item {
    id: root

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) {
        return d && d.type === DeviceType.Wifi;
    }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (root.wifiDev && root.wifiDev.networks) ? root.wifiDev.networks.values : []
    readonly property var wifiActive: root.wifiNets.find(function(n) {
        return n && n.connected;
    }) || null
    readonly property real level: (root.wifiActive && root.wifiActive.signalStrength) || 0
    readonly property int litCount: !root.wifiOn ? 0 : (root.level > 0.66 ? 3 : (root.level > 0.33 ? 2 : (root.level > 0 ? 1 : 0)))
    readonly property color litColor: "#ffffff"
    readonly property color dimColor: Qt.rgba(1, 1, 1, 0.35)
    readonly property real u: Math.min(width, height) / 24
    readonly property real glyphX: arcs.boundingRect.width > 0 ? root.width / 2 - (arcs.boundingRect.x + arcs.boundingRect.width / 2) * root.u : (root.width - 24 * root.u) / 2
    readonly property real glyphY: arcs.boundingRect.height > 0 ? root.height / 2 - (arcs.boundingRect.y + arcs.boundingRect.height / 2) * root.u : (root.height - 24 * root.u) / 2

    visible: root.wifiDev !== null
    implicitWidth: 20
    implicitHeight: 20
    opacity: 0.9
    Accessible.role: Accessible.StaticText
    Accessible.name: !root.wifiOn ? "Wifi off" : (root.wifiActive ? "Wifi connected" : "Wifi on")

    Shape {
        id: arcs

        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: root.glyphX
        y: root.glyphY
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.litCount >= 1 ? root.litColor : root.dimColor
            fillColor: "transparent"
            strokeWidth: 2
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M9.17 13.17 A4 4 0 0 1 14.83 13.17"
            }

        }

        ShapePath {
            strokeColor: root.litCount >= 2 ? root.litColor : root.dimColor
            fillColor: "transparent"
            strokeWidth: 2
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M6.34 10.34 A8 8 0 0 1 17.66 10.34"
            }

        }

        ShapePath {
            strokeColor: root.litCount >= 3 ? root.litColor : root.dimColor
            fillColor: "transparent"
            strokeWidth: 2
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M3.5 7.5 A12 12 0 0 1 20.5 7.5"
            }

        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.litCount >= 1 ? root.litColor : root.dimColor

            PathSvg {
                path: "M12 14.1 A1.5 1.5 0 0 1 12 17.1 A1.5 1.5 0 0 1 12 14.1z"
            }

        }

    }

    Shape {
        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        x: root.glyphX
        y: root.glyphY
        visible: !root.wifiOn
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.6)
            fillColor: "transparent"
            strokeWidth: 1.7
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M4 3 L20 19"
            }

        }

    }

}
