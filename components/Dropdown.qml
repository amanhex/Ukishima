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
 * Active option is the vermilion legend with the flame tick; a second tone
 * marks the row the cursor or pointer is on (`selIndex`) — keyboard moves and
 * pointer hover both tint it, so the selection reads as a colour change, never
 * a cover. `moveSel()`, `pickSel()` and the chip are the keyboard/pointer
 * entry points; the modal click-away scrim lives in the host surface so it can
 * cover the whole strip.
 */
Item {
    id: root

    required property var options
    property var value: ""
    /** The host's SettingsPalette; a null one means the pill's own Theme
     * tokens — every pill surface. The dock's settings panel passes the dock's
     * palette, so the chip and the menu card take the dock's colours and not
     * the pill's. */
    property var pal: null
    property string glyph: ""
    property string title: ""
    property string desc: ""
    property bool open: false
    /** Open the menu above the chip instead of below — for the last row of a
     * surface, where a downward card would hang out of the pill. */
    property bool up: false
    property real s: 1

    signal picked(var value)
    signal chipClicked()

    readonly property int curIndex: {
        for (var i = 0; i < options.length; i++)
            if (String(options[i].value) === String(root.value))
                return i;
        return -1;
    }

    readonly property string curLabel: curIndex >= 0 ? options[curIndex].label : ""

    readonly property color chipGlyph: root.pal ? root.pal.sub : Theme.iconDim
    readonly property color chipInk: root.pal ? root.pal.sub : Theme.subtle
    readonly property color chipFaint: root.pal ? root.pal.faint : Theme.faint
    readonly property color chipActive: root.pal ? root.pal.accent : Theme.vermLit
    readonly property color cardTopCol: root.pal ? root.pal.paneTop : Theme.cardTop
    readonly property color cardBotCol: root.pal ? root.pal.paneBot : Theme.cardBot
    readonly property color rowInk: root.pal ? root.pal.ink : Theme.cream
    readonly property color rowSub: root.pal ? root.pal.sub : Theme.subtle

    readonly property real rowH: 21 * root.s
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
        color: "transparent"
        border.width: 0

        GlyphIcon {
            id: iconGlyph
            anchors.centerIn: parent
            visible: root.glyph.length > 0
            width: 13 * root.s
            height: 13 * root.s
            name: root.glyph
            color: root.open ? root.chipActive : root.chipGlyph
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
                color: root.open ? root.chipActive : root.chipInk
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
            }
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s
                name: root.open ? "chevron-up" : "chevron-down"
                color: root.open ? root.chipActive : root.chipFaint
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
            show: chipHover.hovered && !root.open && (root.title.length > 0 || root.desc.length > 0)
        }
    }

    Item {
        id: menu
        visible: root.open
        z: 60
        anchors.top: root.up ? undefined : chip.bottom
        anchors.topMargin: root.up ? 0 : 6 * root.s
        anchors.bottom: root.up ? chip.top : undefined
        anchors.bottomMargin: root.up ? 6 * root.s : 0
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
                GradientStop { position: 0.0; color: root.cardTopCol }
                GradientStop { position: 1.0; color: root.cardBotCol }
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
                            color: root.chipActive
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            color: row.current ? root.chipActive
                                : (row.index === root.selIndex ? root.rowInk : root.rowSub)
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: row.current ? Font.Bold
                                : (row.index === root.selIndex ? Font.DemiBold : Font.Medium)
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