pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 時 TIMER surface: a countdown for the pill. Pick a length, start it, watch the
 * hero drain and the meter with it; pause or reset any time. The clock lives in
 * the Countdown singleton, so the card can close and reopen without disturbing
 * it, and the end arrives as a notification either way.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 18
    mRight: 18
    mBottom: 15

    implicitHeight: content.implicitHeight

    readonly property int total: Countdown.armedSec
    readonly property real frac: total > 0 ? Math.min(1, Countdown.remaining / total) : 0

    readonly property var presets: [
        { label: "1 min", value: 60 },
        { label: "5 min", value: 5 * 60 },
        { label: "10 min", value: 10 * 60 },
        { label: "15 min", value: 15 * 60 },
        { label: "25 min", value: 25 * 60 },
        { label: "1 hour", value: 60 * 60 }
    ]

    /** mm:ss; the hero never shows an hour, it just runs the minutes up. */
    function clockText(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string actionLabel: Countdown.running ? "Pause"
        : (Countdown.remaining < root.total && Countdown.remaining > 0 ? "Resume" : "Start")

    /**
     * Seam at the head of the drain meter, mirroring the media seek stroke.
     * mapToItem is not reactive, so the voids force a re-eval across the morph
     * and on every tick.
     */
    readonly property point headPoint: {
        void root.width;
        void root.height;
        void Countdown.remaining;
        void meter.width;
        return meter.mapToItem(root, meter.width * root.frac, meter.height / 2);
    }

    ameForm: "seam"
    amePoint: headPoint

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Row {
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "時"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Theme.fontJpWeight
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "TIMER"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.8 * root.s
            }
        }

        Item { width: 1; height: 14 * root.s }

        Text {
            id: hero
            text: root.clockText(Countdown.remaining)
            color: Countdown.running ? Theme.vermLit : Theme.cream
            font.family: Theme.fontMono
            font.pixelSize: 34 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Item { width: 1; height: 11 * root.s }

        Rectangle {
            id: meter
            width: parent.width
            height: 3 * root.s
            radius: height / 2
            color: Theme.frameBg

            Rectangle {
                width: parent.width * root.frac
                height: parent.height
                radius: parent.radius
                color: Theme.vermLit

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                }
            }
        }

        Item { width: 1; height: 14 * root.s }

        Row {
            spacing: 8 * root.s

            Dropdown {
                id: presetDrop
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                options: root.presets
                value: Countdown.presetSec
                onChipClicked: presetDrop.open = !presetDrop.open
                onPicked: (v) => Countdown.choose(v)
            }

            /**
             * The primary action, sized to the longest label it can carry so
             * Start / Pause / Resume never resize the row under the cursor.
             */
            Rectangle {
                id: action
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(actionText.implicitWidth, pauseText.implicitWidth) + 30 * root.s
                height: 26 * root.s
                radius: height / 2
                color: actArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.22) : Theme.tileBg
                border.width: 1
                border.color: actArea.containsMouse ? Qt.alpha(Theme.vermLit, 0.55) : Theme.border

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    id: actionText
                    anchors.centerIn: parent
                    text: root.actionLabel
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                }

                //* Hidden twin, only ever measured, so the button keeps one
                //* width as the label changes.
                Text {
                    id: pauseText
                    visible: false
                    text: "Resume"
                    font: actionText.font
                }

                MouseArea {
                    id: actArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Countdown.toggle()
                }
            }

            IconChip {
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                glyph: "refresh"
                tooltipTitle: "Reset"
                tooltipDesc: "Back to the chosen length"
                onClicked: Countdown.reset()
            }
        }
    }
}
