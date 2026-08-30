pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"

/**
 * Compact header dropdown for the wallpaper strip: a chip that opens a small
 * menu card below it. `options` is a list of `{ label, value }`; the option
 * whose `value` equals `value` is the applied one (flame tick). The chip shows
 * either a `glyph` icon or, when `glyph` is empty, a label chip with the
 * current mode plus a chevron. The host owns open/close coordination via
 * `chipClicked` and the `open` property; selection emits `picked(value)`.
 *
 * Selection motion is a single rounded bar that slides between rows on
 * `selIndex` — keyboard moves and pointer hover both target it, so the
 * highlight glides instead of crossfading per row. `moveSel()`, `pickSel()`
 * and the chip are the keyboard/pointer entry points; the modal click-away
 * scrim lives in the host surface so it can cover the whole strip.
 */
Item {
    id: root

    required property var options
    property string value: ""
    property string glyph: ""
    property string title: ""
    property string desc: ""
    property bool open: false
    property real s: 1

    signal picked(string value)
    signal chipClicked()

    readonly property int curIndex: {
        for (var i = 0; i < options.length; i++)
            if (String(options[i].value) === String(root.value))
                return i;
        return -1;
    }

    readonly property string curLabel: curIndex >= 0 ? options[curIndex].label : ""

    readonly property real rowH: 26 * root.s
    readonly property real chipH: 22 * root.s

    property int selIndex: Math.max(0, curIndex)

    onOpenChanged: if (root.open) root.selIndex = Math.max(0, root.curIndex)

    function moveSel(dir) {
        root.selIndex = Math.max(0, Math.min(options.length - 1, root.selIndex + dir));
    }

    function pickSel() {
        var opt = options[selIndex];
        if (opt === undefined)
            return;
        root.picked(opt.value);
        root.open = false;
    }

    function pickValue(v) {
        root.picked(v);
        root.open = false;
    }

    width: chip.width
    height: chip.height

    Rectangle {
        id: chip
        width: iconGlyph.visible ? root.chipH : chipLabel.implicitWidth + 15 * root.s
        height: root.chipH
        radius: height / 2
        color: root.open ? Qt.alpha(Theme.onGlow, 0.18)
            : (chipHover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: root.open ? Qt.alpha(Theme.onGlow, 0.5)
            : (chipHover.hovered ? Theme.hairSoft : "transparent")
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            id: iconGlyph
            anchors.centerIn: parent
            visible: root.glyph.length > 0
            width: 13 * root.s
            height: 13 * root.s
            name: root.glyph
            color: root.open ? Theme.vermLit : Theme.iconDim
            stroke: 1.8
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Row {
            visible: root.glyph.length === 0
            anchors.centerIn: parent
            spacing: 3 * root.s

            Text {
                id: chipLabel
                text: root.curLabel
                color: root.open ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
            }
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s
                name: root.open ? "chevron-up" : "chevron-down"
                color: root.open ? Theme.vermLit : Theme.faint
            }
        }

        HoverHandler {
            id: chipHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chipClicked()
        }

        Tooltip {
            placement: "below"
            align: "right"
            title: root.title
            desc: root.desc
            show: chipHover.hovered && !root.open
        }
    }

    Item {
        id: menu
        visible: root.open
        z: 60
        anchors.top: chip.bottom
        anchors.topMargin: 6 * root.s
        anchors.right: chip.right

        width: card.width
        height: card.height

        Rectangle {
            anchors.fill: card
            radius: card.radius
            color: Theme.cardBot
            visible: menu.visible
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Rectangle {
            id: card
            anchors.top: parent.top
            anchors.right: parent.right
            width: meas.implicitWidth + 30 * root.s
            height: root.options.length * root.rowH + 4 * root.s
            radius: 9 * root.s
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            border.width: 1
            border.color: Theme.frameBorder

            Rectangle {
                id: selBar
                x: 2 * root.s
                y: 2 * root.s + root.selIndex * root.rowH
                width: card.width - 4 * root.s
                height: root.rowH
                radius: 7 * root.s
                color: Qt.alpha(Theme.onGlow, 0.16)
                border.width: 1
                border.color: Qt.alpha(Theme.onGlow, 0.28)
                Behavior on y { NumberAnimation { duration: Motion.glide; easing.type: Motion.easeStandard } }
                Behavior on width { NumberAnimation { duration: Motion.glide; easing.type: Motion.easeStandard } }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 2 * root.s
                spacing: 0

                Repeater {
                    model: root.options

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData

                        readonly property bool current: String(modelData.value) === String(root.value)

                        width: parent.width
                        height: root.rowH
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6 * root.s
                            visible: row.current
                            width: 2 * root.s
                            height: parent.height * 0.46
                            radius: width / 2
                            color: Theme.vermLit
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: row.index === root.selIndex || row.current ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: row.index === root.selIndex || row.current ? Font.Bold : Font.Medium
                        }

                        HoverHandler {
                            onHoveredChanged: if (hovered) root.selIndex = row.index
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickValue(row.modelData.value)
                        }
                    }
                }
            }
        }
    }

    Text {
        id: meas
        visible: false
        text: {
            var l = "";
            for (var i = 0; i < options.length; i++)
                if (options[i].label.length > l.length)
                    l = options[i].label;
            return l;
        }
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        font.weight: Font.Bold
    }
}