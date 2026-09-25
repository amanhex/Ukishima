import QtQuick
import "../Singletons"

/**
 * Icon-based segmented choice control
 * each option renders a GlyphIcon instead of a text label. `options` is a
 * list of `{ glyph, value, scale?, dx?, dy? }`; picking one emits
 * `picked(value)`. `scale` sizes the glyph within its pill and `dx`/`dy`
 * (in host scale units) nudge it, so each option can be optically centred
 * against the others. `glyphShift` pushes every glyph right within its pill
 * (used to hug a right-aligned edge).
 */

Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    property real glyphShift: 0
    signal picked(var value)

    readonly property real pad: 0
    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: 9 * seg.s
    color: "transparent"

    Row {
        id: pills
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2 * seg.s

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value
                property bool hovered: false

                readonly property real optScale: modelData.scale !== undefined ? modelData.scale : 1
                readonly property real optDx: modelData.dx !== undefined ? modelData.dx : 0
                readonly property real optDy: modelData.dy !== undefined ? modelData.dy : 0

                width: 20 * seg.s
                height: 20 * seg.s
                radius: 7 * seg.s
                color: opt.current ? Qt.alpha(Theme.onGlow, 0.16) : (opt.hovered ? Theme.frameBg : "transparent")
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                GlyphIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (opt.optDx + seg.glyphShift) * seg.s
                    anchors.verticalCenterOffset: opt.optDy * seg.s
                    width: 13 * seg.s * opt.optScale
                    height: 13 * seg.s * opt.optScale
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
