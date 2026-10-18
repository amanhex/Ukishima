pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"
import "../components"

/**
 * The transient centred picker. A faint scrim drops over the whole screen and a
 * small card sits in the middle; picking an option closes it on the spot, and a
 * press on the scrim closes it without choosing. It draws the `Selector`
 * singleton's state and is hosted by the overlay window, so the page that
 * opened it never has to grow to hold it.
 *
 * What the card is choosing is always stated at the top: the centring costs the
 * context the old inline menu borrowed from the row it hung under, and the title
 * pays it back. Every choice then reads as one line — the applied value in the
 * flame ink with a tick, the line the pointer or keyboard sits on wearing the
 * card's only fill — so two options can never both look chosen.
 *
 * Short lists are those lines, tight and stacked; long lists whose lines would
 * run off the screen become wrapping chips under the card's width cap.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    visible: root.active || opacity > 0
    opacity: root.active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

    /** Above this many options a menu would be a column taller than it is wide,
     * so the chips, which wrap, read better. */
    readonly property int menuLimit: 4
    readonly property bool menu: Selector.options.length <= root.menuLimit

    /** Bumped whenever the delegates add, remove or resize, so the width sums
     * below re-read: `itemAt()` is not a tracked dependency. */
    property int optionRev: 0

    /**
     * Widths are read from the delegates' own `naturalW`, not from a
     * positioner's `implicitWidth`. A positioner only refreshes that during a
     * polish pass, so a picker that opens with its options in hand would measure
     * zero and sit at its floor.
     */
    readonly property real menuW: {
        root.optionRev;
        var w = 0;
        for (var i = 0; i < menuRep.count; i++) {
            var it = menuRep.itemAt(i);
            if (it && it.naturalW > w)
                w = it.naturalW;
        }
        return w;
    }

    readonly property real chipsW: {
        root.optionRev;
        var n = chipRep.count;
        if (n === 0)
            return 0;
        var gap = 6 * root.s;
        var total = gap * (n - 1);
        for (var i = 0; i < n; i++) {
            var it = chipRep.itemAt(i);
            if (it)
                total += it.naturalW;
        }
        return total;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.04)

        MouseArea {
            anchors.fill: parent
            enabled: root.active
            acceptedButtons: Qt.AllButtons
            onClicked: Selector.close()
        }
    }

    Rectangle {
        id: card

        objectName: "card"

        readonly property real pad: 12 * root.s
        readonly property real maxW: Math.min(root.width - 80 * root.s, 400 * root.s)
        readonly property real optionsW: root.menu ? root.menuW : root.chipsW
        readonly property real naturalW: Math.max(header.visible ? header.implicitWidth : 0, optionsW) + 2 * pad

        anchors.centerIn: parent
        width: Math.max(200 * root.s, Math.min(maxW, naturalW))
        height: col.implicitHeight + 2 * pad
        radius: 14 * root.s
        color: Theme.cardBot
        border.width: 1
        border.color: Theme.border
        scale: root.active ? 1 : 0.96

        Behavior on scale {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 6 * root.s
        }

        Column {
            id: col

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: card.pad
            spacing: 8 * root.s

            Text {
                id: header

                visible: Selector.title.length > 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Selector.title
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2 * root.s
            }

            /** The band under the title, so the card reads as a titled panel
             * rather than a loose list of words. */
            Rectangle {
                visible: header.visible
                width: parent.width
                height: 1
                color: Theme.hairSoft
            }

            /** A short list: tight lines, the applied one ticked. */
            Column {
                id: menuCol

                visible: root.menu
                width: parent.width
                spacing: 1 * root.s

                Repeater {
                    id: menuRep

                    model: root.menu ? Selector.options : []
                    onItemAdded: root.optionRev++
                    onItemRemoved: root.optionRev++

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool current: String(Selector.value) === String(row.modelData.value)
                        readonly property bool lit: Selector.index === row.index
                        readonly property bool hasIcon: row.modelData.icon !== undefined && String(row.modelData.icon).length > 0
                        readonly property color ink: row.current ? Theme.vermLit : (row.lit ? Theme.cream : Theme.subtle)
                        readonly property real naturalW: 16 * root.s + rowContent.implicitWidth + 47 * root.s

                        onNaturalWChanged: root.optionRev++
                        width: parent.width
                        height: 26 * root.s
                        radius: 8 * root.s
                        /** The card's one fill is the cursor line. The applied
                         * value is told apart by ink and a tick, never a second
                         * fill. */
                        color: row.lit ? Qt.alpha(Theme.vermLit, 0.10) : "transparent"

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Row {
                            id: rowContent

                            anchors.left: parent.left
                            anchors.leftMargin: 16 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7 * root.s

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.hasIcon
                                width: 15 * root.s
                                height: 15 * root.s
                                name: row.hasIcon ? row.modelData.icon : ""
                                color: row.ink
                                stroke: 1.7
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                color: row.ink
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: row.current ? Font.Bold : (row.lit ? Font.DemiBold : Font.Medium)
                            }
                        }

                        GlyphIcon {
                            anchors.right: parent.right
                            anchors.rightMargin: 12 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.current
                            width: 14 * root.s
                            height: 14 * root.s
                            name: "check"
                            color: Theme.vermLit
                            stroke: 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: Selector.index = row.index
                            onClicked: Selector.pick(row.modelData.value)
                        }
                    }
                }
            }

            /** A long list: chips wrapping under the card's width cap, marked
             * by the same rules as the rows. */
            Flow {
                id: flow

                visible: !root.menu
                width: parent.width
                spacing: 6 * root.s

                Repeater {
                    id: chipRep

                    model: root.menu ? [] : Selector.options
                    onItemAdded: root.optionRev++
                    onItemRemoved: root.optionRev++

                    Rectangle {
                        id: chip

                        required property var modelData
                        required property int index

                        readonly property bool current: String(Selector.value) === String(chip.modelData.value)
                        readonly property bool lit: Selector.index === chip.index
                        readonly property bool hasIcon: chip.modelData.icon !== undefined && String(chip.modelData.icon).length > 0
                        readonly property color ink: chip.current ? Theme.vermLit : (chip.lit ? Theme.cream : Theme.subtle)
                        readonly property real naturalW: chipRow.implicitWidth + 20 * root.s

                        onNaturalWChanged: root.optionRev++
                        width: chip.naturalW
                        height: 26 * root.s
                        radius: height / 2
                        color: chip.lit ? Qt.alpha(Theme.vermLit, 0.16) : "transparent"
                        border.width: 1
                        border.color: chip.lit ? Qt.alpha(Theme.vermLit, 0.30)
                                    : (chip.current ? Qt.alpha(Theme.vermLit, 0.55) : Theme.border)

                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: 6 * root.s

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.current
                                width: 12 * root.s
                                height: 12 * root.s
                                name: "check"
                                color: Theme.vermLit
                                stroke: 2.2
                            }

                            GlyphIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.hasIcon
                                width: 14 * root.s
                                height: 14 * root.s
                                name: chip.hasIcon ? chip.modelData.icon : ""
                                color: chip.ink
                                stroke: 1.7
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label
                                color: chip.ink
                                font.family: Theme.font
                                font.pixelSize: 10.5 * root.s
                                font.weight: chip.current ? Font.Bold : (chip.lit ? Font.DemiBold : Font.Medium)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: Selector.index = chip.index
                            onClicked: Selector.pick(chip.modelData.value)
                        }
                    }
                }
            }
        }
    }
}
