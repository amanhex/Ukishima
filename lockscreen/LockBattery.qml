import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower

/**
 * Lockscreen battery (top-right): the Tide-style MiniBattery artwork
 * (components/MiniBattery.qml) ported self-contained — the lockscreen runs
 * as a separate process that cannot import Singletons/, components/ or
 * Theme (singletons are per-process), so metrics and the bolt vector are
 * baked here. Colors are baked to match the pill-side widget; keep the
 * geometry and colors in sync by hand: 37x17 body, 6px radius, % centred
 * over the fill, bolt + % overlay while actually charging (hidden once
 * full), green fill, red at or below 20%. `shimmerOn` (driven by
 * LockSurface from the shared flags) runs the shadcn sweep below; the
 * animation stays off when full or unplugged.
 */
Item {
    //* Bolt drawn natively in the 10px box (a 24-unit vector would not
    //* auto-scale inside PathSvg and would clip). Mirrors the "bolt" glyph
    //* from components/GlyphIcon.qml in stroked style.

    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property int pct: dev ? Math.round(Math.max(0, Math.min(1, dev.percentage)) * 100) : 0
    readonly property int chargeState: dev ? dev.state : UPowerDeviceState.Unknown
    //* True while current is flowing in: Charging and not yet full. A full
    //* battery reports FullyCharged (sysfs "Not charging" maps there too),
    //* and pct >= 100 covers drivers that never leave the Charging state.
    readonly property bool full: root.chargeState === UPowerDeviceState.FullyCharged || root.pct >= 100
    readonly property bool charging: root.chargeState === UPowerDeviceState.Charging && !root.full
    readonly property bool onAc: root.charging || root.full || root.chargeState === UPowerDeviceState.PendingCharge
    //* Sweeps the charging overlay; LockSurface drives this from the shared
    //* flags (batteryShimmer && !reduceMotion).
    property bool shimmerOn: true
    readonly property bool sheenActive: root.charging && root.shimmerOn
    readonly property bool low: root.pct <= 20
    readonly property bool roundedEnd: root.pct >= 85

    visible: root.present
    implicitWidth: 37
    implicitHeight: 30
    Accessible.role: Accessible.StaticText
    Accessible.name: "Battery " + root.pct + " percent" + (root.charging ? ", charging" : (root.full ? ", fully charged" : ""))

    Rectangle {
        id: body

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 17
        radius: 6
        color: "#59ffffff"
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            topLeftRadius: 6
            bottomLeftRadius: 6
            topRightRadius: root.roundedEnd ? 6 : 0
            bottomRightRadius: root.roundedEnd ? 6 : 0
            width: Math.max(12, parent.width * root.pct / 100)
            color: root.low ? "#ff3b30" : "#34c759"

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 300
                }

            }

        }

        //* Charging overlay: % + bolt under a shadcn sweep (dim base + bright
        //* highlight sliding across in a 2s linear loop), ported from the
        //* lockscreen "Authenticating" sheen. Hidden once full or unplugged;
        //* the plain % below takes over instead.
        Item {
            id: chargeShimmer

            anchors.centerIn: parent
            width: chargeBase.implicitWidth
            height: chargeBase.implicitHeight
            visible: root.charging
            z: 2

            ChargeRow {
                id: chargeBase

                anchors.centerIn: parent
                tint: "#ffffff"
                opacity: root.sheenActive ? 0.55 : 1
            }

            Item {
                id: sheenMover

                readonly property real coreWidth: Math.max(10, chargeShimmer.width * 0.3)

                width: Math.max(20, chargeShimmer.width * 0.6)
                height: chargeShimmer.height
                visible: root.sheenActive

                Item {
                    anchors.fill: parent
                    clip: true

                    ChargeRow {
                        y: (chargeShimmer.height - height) / 2
                        x: (chargeShimmer.width - implicitWidth) / 2 - sheenMover.x
                        width: implicitWidth
                        height: implicitHeight
                        tint: "#ffffff"
                        opacity: 0.45
                    }

                }

                Item {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: sheenMover.coreWidth
                    clip: true

                    ChargeRow {
                        y: (chargeShimmer.height - height) / 2
                        x: (chargeShimmer.width - implicitWidth) / 2 - sheenMover.x - (sheenMover.width - sheenMover.coreWidth) / 2
                        width: implicitWidth
                        height: implicitHeight
                        tint: "#ffffff"
                    }

                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.sheenActive

                    PauseAnimation {
                        duration: 250
                    }

                    NumberAnimation {
                        from: -sheenMover.width
                        to: chargeShimmer.width
                        duration: 2000
                        easing.type: Easing.Linear
                    }

                }

            }

        }

        Text {
            anchors.centerIn: parent
            visible: !root.charging
            z: 2
            text: root.pct + ""
            color: "#ffffff"
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.weight: root.low ? Font.Bold : Font.DemiBold
        }

    }

    Rectangle {
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 5
        radius: 1
        color: root.pct >= 100 ? (root.low ? "#ff3b30" : "#34c759") : "#59ffffff"

        Behavior on color {
            ColorAnimation {
                duration: 300
            }

        }

    }

    //* One % + bolt row, instantiated 3x by the sheen below (dim base, faint
    //* halo copy, bright core copy) so the sliding highlight stays registered
    //* over the text, exactly like the lockscreen "Authenticating" sheen.
    component ChargeRow: Row {
        property color tint: "#ffffff"

        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pct + ""
            color: tint
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Shape {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: tint
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                PathSvg {
                    path: "M6.5 1 L2.5 5.8 h2.5 L4.6 9.2 L8 4.6 H5.5 Z"
                }

            }

        }

    }

}
