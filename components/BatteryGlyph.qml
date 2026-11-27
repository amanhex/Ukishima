import QtQuick
import "../Singletons"

/**
 * Compact battery readout: a slim shell, a level fill and a terminal nub, with
 * a bolt over the cell while charging. Sized in `s` units so the bar and the
 * status face share one drawing. `frac` is 0..1; `low` and `charging` tint the
 * cell with the alert colour, matching the text beside it.
 *
 * The nub sits flush on the shell's edge (no gap): a detached terminal reads
 * as a second cell at bar size, which is what made the old drawing look wrong.
 */
Item {
    id: root

    property real s: 1
    property real frac: 0
    property bool charging: false
    property bool low: false
    /** Fill and bolt colour; the shell is this at 65%. */
    property color color: Theme.cream

    implicitWidth: 20 * s
    implicitHeight: 10 * s

    Rectangle {
        id: shell
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 18 * root.s
        height: 9.5 * root.s
        radius: 2 * root.s
        color: "transparent"
        border.width: 1.25 * root.s
        border.color: root.low ? Theme.vermLit : Qt.alpha(root.color, 0.7)
    }
    Rectangle {
        anchors.left: shell.left
        anchors.leftMargin: 1.6 * root.s
        anchors.verticalCenter: shell.verticalCenter
        width: Math.max(0, (shell.width - 3.2 * root.s) * Math.max(0, Math.min(1, root.frac)))
        height: shell.height - 3.2 * root.s
        radius: 0.8 * root.s
        color: root.low ? Theme.vermLit
            : (root.charging ? Qt.alpha(root.color, 0.55) : root.color)
    }
    GlyphIcon {
        anchors.centerIn: shell
        visible: root.charging
        width: 7 * root.s
        height: 7 * root.s
        name: "bolt"
        color: root.color
        stroke: 1.6
    }
    Rectangle {
        anchors.left: shell.right
        anchors.verticalCenter: shell.verticalCenter
        width: 1.8 * root.s
        height: 3.2 * root.s
        radius: 0.6 * root.s
        color: shell.border.color
    }
}
