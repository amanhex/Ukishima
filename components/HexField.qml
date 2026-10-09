pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"

/**
 * Manual #hex entry row shared by the dock's and the pill's manual-palette
 * rows: an underlined field that parses on Enter (or blur) and emits
 * `committed(hue, sat)` with hue -1 when the colour has no hue (black/white).
 * Enter/Space are swallowed so they apply instead of leaking into the host's
 * settings-activate handler.
 */
Item {
    id: root

    property real s: 1
    property string placeholder: ""
    property color ink: Theme.cream
    property color faint: Theme.faint
    property color accent: Theme.verm
    signal committed(var hue, real sat)

    width: parent.width
    height: 30 * root.s

    Text {
        id: hexHint
        anchors.left: parent.left
        anchors.leftMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        text: "#"
        color: root.faint
        font.family: Theme.font
        font.pixelSize: 14 * root.s
        font.weight: Font.DemiBold
    }

    TextField {
        id: hexField
        anchors.left: hexHint.right
        anchors.leftMargin: 6 * root.s
        anchors.right: parent.right
        anchors.rightMargin: 12 * root.s
        anchors.verticalCenter: parent.verticalCenter
        background: null
        padding: 0
        color: root.ink
        font.family: Theme.font
        font.pixelSize: 13 * root.s
        font.features: { "tnum": 1 }
        placeholderText: root.placeholder
        placeholderTextColor: root.faint
        selectByMouse: true
        selectionColor: root.accent
        maximumLength: 7

        onActiveFocusChanged: if (!activeFocus) text = "";

        function doCommit() {
            var c = Theme.parseHex(text);
            if (c) {
                if (c.hslHue >= 0)
                    /* QML color hslHue/hslSaturation are 0-1 fractions;
                     * the strip stores hue 0-359 and sat 0-1. */
                    root.committed(Math.round(c.hslHue * 359), Math.min(1, c.hslSaturation));
                else
                    root.committed(-1, 0);
            }
            text = "";
            focus = false;
        }

        onAccepted: doCommit()
        onEditingFinished: doCommit()

        /* Enter/Space must apply, not leak into the surface's row activation
         * (which would toggle the focused manual row and revert the hex).
         * Accepting the key at the field stops it before the shell's
         * settings-activate handler sees it. */
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                doCommit();
                e.accepted = true;
            } else if (e.key === Qt.Key_Space) {
                e.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.left: hexField.left
        anchors.right: hexField.right
        anchors.top: hexField.bottom
        anchors.topMargin: 3 * root.s
        height: 1
        color: root.faint
        opacity: hexField.activeFocus ? 0.7 : 0.18
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    }
}