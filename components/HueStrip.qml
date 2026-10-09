pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * Horizontal hue slider used by the dock's and the pill's manual-palette rows:
 * the six-stop hue gradient with a draggable thumb. The host owns the hue and
 * sat values (bindings read here); a click or drag emits `huePicked` and, when
 * the sat is too low to show a hue, `satSeeded` first so the host can lift it.
 */
Item {
    id: root

    property real s: 1
    property real hue: 0
    property real sat: 1
    property color thumbColor
    property color thumbBorder
    signal huePicked(real hue)
    signal satSeeded()

    width: parent.width
    height: 14 * root.s

    Rectangle {
        id: strip
        anchors.fill: parent
        radius: 7 * root.s
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
            GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
            GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
            GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
            GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
            GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
            GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
        }

        Rectangle {
            id: thumb
            width: 16 * root.s
            height: 16 * root.s
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: (root.hue / 359) * (strip.width - width)
            color: root.thumbColor
            border.width: 2.5 * root.s
            border.color: root.thumbBorder
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function setHue(mx) {
                if (root.sat < 0.05)
                    root.satSeeded();
                root.huePicked(Math.round(Math.max(0, Math.min(1, mx / strip.width)) * 359));
            }
            onPressed: (mouse) => setHue(mouse.x)
            onPositionChanged: (mouse) => setHue(mouse.x)
        }
    }
}