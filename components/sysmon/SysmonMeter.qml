pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea-style level meter: a flat verm gradient bar, optionally under a tick
 * ruler or replaced by a row of lit segments. `value` is 0-100; a negative
 * value draws nothing (used by stat rows that have no meaningful total).
 * `host` is SysmonSurface (for the scale).
 */
Item {
    id: meter

    property var host: null
    property real value: -1
    property color accent: Theme.vermLit
    property bool ruler: false
    property int segments: 0
    readonly property real s: meter.host ? meter.host.s : 1
    readonly property real frac: Math.max(0, Math.min(1, meter.value / 100))

    implicitHeight: meter.segments > 0 ? 7 * meter.s : (meter.ruler ? 10 * meter.s : 4 * meter.s)
    visible: meter.value >= 0

    Row {
        id: ticks
        visible: meter.ruler && meter.segments === 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4 * meter.s
        spacing: Math.max(0, (width - 33 * meter.s) / 32)

        Repeater {
            model: 33
            delegate: Rectangle {
                required property int index
                width: 1 * meter.s
                height: (index % 5 === 0 ? 4 : 2) * meter.s
                color: Theme.faint
            }
        }
    }

    Rectangle {
        visible: meter.segments === 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2 * meter.s
        color: Theme.hair
    }

    Rectangle {
        visible: meter.segments === 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * meter.frac
        height: 2 * meter.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.vermBurn }
            GradientStop { position: 1.0; color: meter.accent }
        }
    }

    Row {
        id: segRow
        visible: meter.segments > 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 2 * meter.s
        readonly property real cellW: Math.max(1, (width - (meter.segments - 1) * spacing) / meter.segments)

        Repeater {
            model: meter.segments
            delegate: Rectangle {
                required property int index
                width: segRow.cellW
                height: 5 * meter.s
                color: index < Math.round(meter.frac * meter.segments) ? meter.accent : Theme.hair
            }
        }
    }
}
