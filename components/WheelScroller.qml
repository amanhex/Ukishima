import QtQuick

/**
 * Wheel-to-Flickable bridge for layer-shell surfaces, where the native
 * WheelHandler path is unreliable: a button-less MouseArea converts wheel
 * notches into clamped content steps on the target Flickable. Set `horizontal`
 * for a row that scrolls sideways.
 */
MouseArea {
    id: root

    property real s: 1
    property bool horizontal: false
    required property Flickable flick

    acceptedButtons: Qt.NoButton

    onWheel: function(event) {
        var step = event.angleDelta.y / 120 * 36 * s;
        if (root.horizontal) {
            var maxX = Math.max(0, flick.contentWidth - flick.width);
            flick.contentX = Math.max(0, Math.min(maxX, flick.contentX - step));
        } else {
            var maxY = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - step));
        }
        event.accepted = true;
    }
}
