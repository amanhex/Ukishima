pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * Battery thread primitive for the link surface, matches the mixer fader's
 * filament look: one thin horizontal thread with a warm fill. level is 0..1.
 */
Item {
    id: root

    property real s: 1
    property real level: 0

    implicitWidth: 22 * s
    implicitHeight: 3 * s

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 22 * root.s
        height: 3 * root.s
        radius: height / 2
        color: Theme.threadBg

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1, root.level))
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.vermDim }
                GradientStop { position: 1.0; color: Theme.vermLit }
            }
        }
    }
}
