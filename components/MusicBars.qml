pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * Rest-pill spectrum: one rounded ember bar per cava band, packed into the
 * clock-glyph slot so the cluster never widens the pill. Heights chase
 * Cava.levels with a short ease so the motion stays liquid instead of strobing
 * on every frame cava emits.
 */
Row {
    id: root

    property real s: 1
    property real span: 18

    height: span * s
    spacing: 1.2 * s

    Repeater {
        model: Cava.bars

        Rectangle {
            required property int index

            width: 1.8 * root.s
            radius: width / 2
            anchors.bottom: parent.bottom
            height: Math.max(2 * root.s, (Cava.levels[index] || 0) * root.span * root.s)

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.flameGlow }
                GradientStop { position: 1.0; color: Theme.vermLit }
            }

            Behavior on height {
                enabled: root.visible
                NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad }
            }
        }
    }
}
