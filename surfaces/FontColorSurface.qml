pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 字 FONT COLOUR sub-surface: the optional text override. A custom hex recolours
 * the primary text family — cream and bright on the pill, the dock's title copy —
 * wherever the scheme would apply, while the muted secondaries (dim, faint,
 * iconDim) keep their own values so sub-copy stays legible beside a custom
 * colour. The row pairs a live swatch preview with the Custom toggle and
 * unfolds hue/saturation sliders, a live swatch and a hex field for exact entry.
 * Reached from the Appearance index and folds back to it on the back chevron or
 * an empty click.
 *
 * The sliders are native QtQuick Controls sliders that recolor live while the
 * drag is held and always re-commit on release (`onMoved`), so a fast scrub can
 * never be lost to the adapter's async write.
 */
SettingsSurface {
    id: root

    backSurface: "appcat"
    implicitHeight: content.implicitHeight

    /** Text override on: a custom hex is pinned and wins over every palette mode. */
    readonly property bool fontCustom: Flags.textOverride.length > 0

    /** The live text colour — the pinned hex when custom, else the scheme's. */
    readonly property color fontColorValue: root.fontCustom ? Flags.textOverride : Theme.cream
    /* QML color hsl* are 0-1 fractions in this build (not 0-359/0-255); the
     * guards collapse undefined hues (grayscale/black report NaN) to 0.
     * Saturation keeps a visibility floor (0.3) so the sat handle stays
     * draggable from a grey seed. The working lightness is FIXED at 0.5 — the
     * same level the slider tracks themselves paint at — because the scheme's
     * text colours sit near-white (dark) or near-black (light): preserving
     * their lightness made every hue/saturation drag land as a pale pastel
     * instead of the colour shown on the track. What you see is what the text
     * gets; pick an exact shade with the hex field instead. */
    readonly property real fontHue01: fontColorValue.hslHue >= 0 ? Math.min(1, fontColorValue.hslHue) : 0
    readonly property real fontSat01: fontColorValue.hslSaturation >= 0 ? Math.max(0.3, Math.min(1, fontColorValue.hslSaturation)) : 0.3
    readonly property real fontWorkLight01: 0.5
    /* The knob fill stays a fixed light grey instead of the live colour so the
     * circle never disappears into the track it sits on (the track paints the
     * picked colour, so a self-tinted knob would blend right in). A soft dark
     * ring keeps the edge visible even over the lightest track segments. */
    readonly property color sliderKnob: "#e6e6e6"
    readonly property color sliderKnobRing: Qt.rgba(0, 0, 0, 0.45)

    /* The one hex conversion lives in Theme; see `hexUpper` there for why it is
     * not a private copy per surface. */
    function rgbHex(c) {
        return Theme.hexUpper(c);
    }

    /** Row caption: custom state, plus the scheme text colour when following it. */
    readonly property string fontSub: root.fontCustom
        ? "Custom · " + Flags.textOverride.toUpperCase()
        : ("Follows theme · " + root.rgbHex(Theme.cream))

    function setFontCustom(on) {
        if (on) {
            if (Flags.textOverride.length === 0)
                Flags.textOverride = root.rgbHex(Theme.cream);
            fontHueSlider.value = root.fontHue01;
            fontSatSlider.value = root.fontSat01;
        } else {
            Flags.textOverride = "";
        }
    }

    /** Rebuild the pinned hex from hue (0-359) / sat (0-1) / light (0-1). */
    function setFontHsl(hDeg, s01, l01) {
        var hue01 = Math.max(0, Math.min(1, hDeg / 360));
        /* Floor sat/light so a drag from a degenerate (black/gray) seed never
         * writes #000000 — the sliders must always produce a visible colour. */
        var col = Qt.hsla(hue01, Math.max(0.05, Math.min(1, s01)), Math.max(0.05, Math.min(1, l01)), 1);
        Flags.textOverride = root.rgbHex(col);
    }

    rows: [
        { item: fontRow, kind: "toggle", get: function () { return root.fontCustom; }, set: function (v) { root.setFontCustom(v); } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "字"
            title: "FONT COLOUR"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        /**
         * Text colour: an optional user hex that recolours the primary text family
         * (cream/bright on the pill, the dock's title copy) over the scheme's.
         * Turning Custom on seeds from the current text colour and unfolds the
         * picker below. The chip in the row previews the live text colour either way.
         */
        SettingsRow {
            id: fontRow
            surface: root
            name: "Font colour"
            icon: "type"
            sub: root.fontSub

            Item {
                width: fontChip.width + 10 * root.s + fontToggle.width
                height: 26 * root.s

                Rectangle {
                    id: fontChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * root.s
                    height: 20 * root.s
                    radius: 6 * root.s
                    color: root.fontColorValue
                    border.width: 1
                    border.color: Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                LinkToggle {
                    id: fontToggle
                    anchors.left: fontChip.right
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: root.fontCustom
                    onToggled: root.setFontCustom(!root.fontCustom)
                }
            }
        }

        /**
         * The text picker, folded shut unless Custom is on. Hue and saturation
         * are native QtQuick Controls sliders: they recolor live while held
         * (`pressed`) and re-commit on release (`onMoved`) so the final position
         * always lands. The row beneath pairs a live swatch with the hex field
         * for exact entry, and typing keeps both sliders in sync.
         */
        Item {
            id: fontSection
            width: parent.width
            height: root.fontCustom ? fontPanel.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: fontPanel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12 * root.s
                anchors.rightMargin: 12 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                Item {
                    width: parent.width
                    height: 26 * root.s

                    Slider {
                        id: fontHueSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setFontHsl(Math.round(fontHueSlider.value * 359), root.fontSat01, root.fontWorkLight01)
                        onMoved: root.setFontHsl(Math.round(fontHueSlider.value * 359), root.fontSat01, root.fontWorkLight01)
                        Component.onCompleted: fontHueSlider.value = root.fontHue01

                        background: Rectangle {
                            y: fontHueSlider.availableHeight / 2 - 7 * root.s
                            width: fontHueSlider.availableWidth
                            height: 14 * root.s
                            radius: 7 * root.s
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.7, 0.5, 1) }
                                GradientStop { position: 1 / 6; color: Qt.hsla(1 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 2 / 6; color: Qt.hsla(2 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 3 / 6; color: Qt.hsla(3 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 4 / 6; color: Qt.hsla(4 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 5 / 6; color: Qt.hsla(5 / 6, 0.7, 0.5, 1) }
                                GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.7, 0.5, 1) }
                            }
                        }
                        handle: Rectangle {
                            x: fontHueSlider.leftPadding + fontHueSlider.visualPosition * (fontHueSlider.availableWidth - width)
                            y: fontHueSlider.availableHeight / 2 - height / 2
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: root.sliderKnob
                            border.width: 2.5 * root.s
                            border.color: root.sliderKnobRing
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 26 * root.s

                    Slider {
                        id: fontSatSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setFontHsl(root.fontHue01 * 359, fontSatSlider.value, root.fontWorkLight01)
                        onMoved: root.setFontHsl(root.fontHue01 * 359, fontSatSlider.value, root.fontWorkLight01)
                        Component.onCompleted: fontSatSlider.value = root.fontSat01

                        background: Rectangle {
                            y: fontSatSlider.availableHeight / 2 - 7 * root.s
                            width: fontSatSlider.availableWidth
                            height: 14 * root.s
                            radius: 7 * root.s
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsla(root.fontHue01, 0.0, 0.5, 1) }
                                GradientStop { position: 0.5; color: Qt.hsla(root.fontHue01, 0.5, 0.5, 1) }
                                GradientStop { position: 1.0; color: Qt.hsla(root.fontHue01, 1.0, 0.5, 1) }
                            }
                        }
                        handle: Rectangle {
                            x: fontSatSlider.leftPadding + fontSatSlider.visualPosition * (fontSatSlider.availableWidth - width)
                            y: fontSatSlider.availableHeight / 2 - height / 2
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: root.sliderKnob
                            border.width: 2.5 * root.s
                            border.color: root.sliderKnobRing
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, fontHexField.implicitHeight)

                    Rectangle {
                        id: fontPickSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.fontColorValue
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        id: fontHexHint
                        anchors.left: fontPickSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: fontHexField
                        anchors.left: fontHexHint.right
                        anchors.leftMargin: 6 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                        font.features: { "tnum": 1 }
                        selectByMouse: true
                        selectionColor: Theme.verm
                        maximumLength: 6

                        onActiveFocusChanged: if (!activeFocus) text = "";

                        function commit() {
                            var c = Theme.parseHex(text);
                            if (c) {
                                Flags.textOverride = Theme.hexUpper(c);
                                fontHueSlider.value = root.fontHue01;
                                fontSatSlider.value = root.fontSat01;
                            }
                            text = "";
                            focus = false;
                        }

                        onAccepted: commit()
                        onEditingFinished: commit()

                        /* Enter/Space must apply, not leak into the surface's row
                         * activation (which would flip the Custom toggle and revert
                         * the hex). Accepting the key at the field stops it before
                         * the shell's settings-activate handler sees it. */
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                commit();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Space) {
                                e.accepted = true;
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: fontHexField.left
                        anchors.right: fontHexField.right
                        anchors.top: fontHexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: fontHexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }
    }
}