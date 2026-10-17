pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 時 TIMER surface: a countdown for the pill, drawn in the same language as the
 * recorder — a stage card carrying the clock and its drain meter, an options
 * card of hairline rows, and the gradient action bar underneath. A length is
 * picked from the preset chips or typed into the custom field in minutes; the
 * clock itself lives in the Countdown singleton, so the card can close and
 * reopen (or the daemon restart the surface) without disturbing it, and the end
 * arrives as a notification either way.
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

    /** The preset lengths in minutes, and whether the armed one is a preset. */
    readonly property var presetMins: [1, 5, 10, 15, 25]
    readonly property bool customArmed: presetMins.indexOf(Math.round(Countdown.presetSec / 60)) < 0

    readonly property string actionLabel: Countdown.running ? "Pause"
        : (Countdown.remaining > 0 && Countdown.remaining < root.total ? "Resume" : "Start")

    readonly property string stateLabel: Countdown.running ? "RUNNING"
        : (Countdown.remaining > 0 && Countdown.remaining < root.total ? "PAUSED" : "READY")

    /** mm:ss; the hero runs the minutes up rather than ever showing an hour. */
    function clockText(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    /**
     * Take up whatever is typed in the custom field and blank it, for every
     * caller that is about to run or re-arm the clock — the action bar, a
     * reset, a preset pick. A MouseArea does not steal focus, so the field
     * keeps its text when the bar is tapped; without this a number under the
     * cursor would be ignored by the very button it was typed for.
     */
    function commitCustom() {
        const m = parseInt(minField.text);
        if (m >= 1 && m <= 600)
            Countdown.choose(m * 60);
        minField.text = "";
    }

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

    /**
     * Mini-segmented choice control, copied from Settings and the recorder:
     * `options` is a list of `{ label, value }`; the pill whose value equals
     * `value` lights with a solid card-top fill and cream text.
     */
    component MiniSeg: Rectangle {
        id: seg
        property var options: []
        property var value
        signal picked(var value)

        readonly property real pad: 2 * root.s

        width: pills.implicitWidth + 2 * pad
        height: pills.implicitHeight + 2 * pad
        radius: 9 * root.s
        color: "transparent"

        Row {
            id: pills
            anchors.centerIn: parent
            spacing: 2 * root.s

            Repeater {
                model: seg.options

                Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool current: seg.value === modelData.value

                    width: optLabel.implicitWidth + 18 * root.s
                    height: optLabel.implicitHeight + 12 * root.s
                    radius: 7 * root.s
                    color: opt.current ? Theme.cardTop : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        id: optLabel
                        anchors.centerIn: parent
                        text: opt.modelData.label
                        color: opt.current ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(opt.modelData.value)
                    }
                }
            }
        }
    }

    /**
     * One options-card line: a cream label on the left and a control pushed to
     * the right, capped by a top hairline on every row but the first.
     */
    component ORow: Item {
        id: orow
        property string name: ""
        property bool first: false
        default property alias control: controlSlot.data

        width: parent ? parent.width : 0
        height: 35 * root.s

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
            visible: !orow.first
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: orow.name
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Item {
            id: controlSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        /** Header: the kanji and name left, the run state right, as the recorder. */
        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
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

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.s

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Countdown.running
                    width: 7 * root.s
                    height: 7 * root.s
                    radius: width / 2
                    color: Theme.verm
                    SequentialAnimation on opacity {
                        running: Countdown.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stateLabel
                    color: Countdown.running ? Theme.vermLit : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        /** Stage card: the clock over its drain meter, as the recorder's stage. */
        Rectangle {
            id: stage

            readonly property real padTop: 13 * root.s
            readonly property real padBottom: 16 * root.s
            readonly property real gap: 12 * root.s

            width: parent.width
            height: stageCol.implicitHeight + padTop + gap + meter.height + padBottom
            radius: 13 * root.s
            color: Theme.cardBot

            Column {
                id: stageCol
                anchors.top: parent.top
                anchors.topMargin: stage.padTop
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.clockText(Countdown.remaining)
                    color: Countdown.running ? Theme.vermLit : Theme.cream
                    font.family: Theme.fontMono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "of " + Math.round(root.total / 60) + " min"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.features: { "tnum": 1 }
                }
            }

            Rectangle {
                id: meter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22 * root.s
                anchors.rightMargin: 22 * root.s
                anchors.bottomMargin: stage.padBottom
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
        }

        Item { width: 1; height: 13 * root.s }

        /** Options card: the preset chips and the custom length, as drawer rows. */
        Rectangle {
            width: parent.width
            height: opts.implicitHeight + 16 * root.s
            radius: 13 * root.s
            color: Theme.cardBot

            Column {
                id: opts
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16 * root.s
                anchors.rightMargin: 14 * root.s
                anchors.verticalCenter: parent.verticalCenter

                ORow {
                    name: "Preset"
                    first: true
                    MiniSeg {
                        options: [
                            { label: "1", value: 1 },
                            { label: "5", value: 5 },
                            { label: "10", value: 10 },
                            { label: "15", value: 15 },
                            { label: "25", value: 25 }
                        ]
                        value: Math.round(Countdown.presetSec / 60)
                        onPicked: (v) => { root.commitCustom(); Countdown.choose(v * 60); }
                    }
                }

                /**
                 * A length off the presets is typed here in minutes and taken
                 * up by Return, the action bar, a reset or a preset pick — all
                 * of them run `commitCustom`, which also blanks the field so
                 * the pill reads as a prompt again (HexField's
                 * commit-and-blank), showing the armed minutes faintly while
                 * there is one. Enter and Space are swallowed so they apply
                 * instead of leaking into the pill's key handling.
                 */
                ORow {
                    name: "Custom"
                    Rectangle {
                        width: 98 * root.s
                        height: 26 * root.s
                        radius: height / 2
                        color: Theme.tileBg
                        border.width: 1
                        border.color: minField.activeFocus ? Qt.alpha(Theme.vermLit, 0.55) : Theme.border

                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                        TextField {
                            id: minField
                            anchors.fill: parent
                            anchors.leftMargin: 13 * root.s
                            anchors.rightMargin: 11 * root.s
                            background: null
                            padding: 0
                            color: Theme.cream
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.features: { "tnum": 1 }
                            placeholderText: root.customArmed
                                ? Math.round(Countdown.presetSec / 60) + " min" : "min"
                            placeholderTextColor: Theme.faint
                            selectByMouse: true
                            selectionColor: Qt.alpha(Theme.verm, 0.5)

                            function doCommit() {
                                root.commitCustom();
                                focus = false;
                            }
                            onAccepted: doCommit()
                            onEditingFinished: doCommit()
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    doCommit();
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Space) {
                                    e.accepted = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 13 * root.s }

        /** Action bar: the run control on the recorder's vermilion gradient. */
        Rectangle {
            id: actionBar
            width: parent.width
            height: 44 * root.s
            radius: 14 * root.s
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Countdown.running ? Qt.alpha(Theme.verm, 0.34) : Qt.alpha(Theme.verm, 0.2) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.09) }
            }

            Item {
                anchors.left: parent.left
                anchors.right: resetChip.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                scale: actArea.pressed ? 0.984 : 1

                Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 20 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s
                        height: 12 * root.s
                        name: Countdown.running ? "pause" : "play"
                        color: Theme.cream
                        stroke: 2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.actionLabel
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5 * root.s
                    }
                }

                MouseArea {
                    id: actArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.commitCustom();
                        Countdown.toggle();
                    }
                }
            }

            IconChip {
                id: resetChip
                anchors.right: parent.right
                anchors.rightMargin: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                glyph: "refresh"
                tooltipTitle: "Reset"
                tooltipDesc: "Back to the armed length"
                onClicked: {
                    root.commitCustom();
                    Countdown.reset();
                }
            }
        }
    }
}
