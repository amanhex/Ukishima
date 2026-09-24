import QtQuick
import "../Singletons"

/**
 * Icon-based segmented choice control
 * each option renders a GlyphIcon instead of a text label. `options` is a
 * list of `{ glyph, value }`; picking one emits `picked(value)`.
 */
Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    readonly property real pad: 1
    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: 9 * seg.s
    color: "transparent"

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 2 * seg.s

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value
                property bool hovered: false

                width: 26 * seg.s
                height: 26 * seg.s
                radius: 8 * seg.s
                color: opt.current ? Qt.alpha(Theme.onGlow, 0.16) : (opt.hovered ? Theme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 15 * seg.s
                    height: 15 * seg.s
                    name: opt.modelData.glyph
                    color: opt.current ? Theme.cream : Theme.subtle
                    stroke: 1.7
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: opt.hovered = true
                    onExited: opt.hovered = false
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}