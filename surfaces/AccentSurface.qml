pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * 彩 ACCENT sub-surface: the optional accent override. A custom hex pins the
 * warm family (glow, verm ramps, flame ink, today cell) to one colour that wins
 * over whatever the Light/Dark/default, the wallpaper accent or the manual hue
 * would pick. The row pairs a live swatch preview with the Custom toggle and
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

    /** Accent override on: a custom hex is pinned and wins over every palette mode. */
    readonly property bool accentCustom: Flags.accentOverride.length > 0

    /** The live accent colour — the pinned hex when custom, else the scheme's. */
    readonly property color accentColorValue: root.accentCustom ? Flags.accentOverride : Theme.accent
    /* QML color hsl* are 0-1 fractions in this build (not 0-359/0-255); the
     * guards collapse undefined hues (grayscale/black report NaN) to 0.
     * The sat/light values carry a visibility floor: with only hue and
     * saturation sliders there is no lightness control, so a black or grey
     * accent typed into the hex field would otherwise be unmovable — every
     * drag would write black again. Flooring the working sat/light makes any
     * slider change from a degenerate accent land on a clearly visible colour. */
    readonly property real accentHue01: accentColorValue.hslHue >= 0 ? Math.min(1, accentColorValue.hslHue) : 0
    readonly property real accentSat01: accentColorValue.hslSaturation >= 0 ? Math.max(0.3, Math.min(1, accentColorValue.hslSaturation)) : 0.3
    readonly property real accentLight01: accentColorValue.hslLightness >= 0 ? Math.max(0.35, Math.min(1, accentColorValue.hslLightness)) : 0.35
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

    /** Row caption: custom state, plus the scheme accent when following it. */
    readonly property string accentSub: root.accentCustom
        ? "Custom · " + Flags.accentOverride.toUpperCase()
        : ("Follows theme · " + root.rgbHex(Theme.accent))

    function setAccentCustom(on) {
        if (on) {
            if (Flags.accentOverride.length === 0)
                Flags.accentOverride = root.rgbHex(Theme.accent);
            accentHueSlider.value = root.accentHue01;
            accentSatSlider.value = root.accentSat01;
        } else {
            Flags.accentOverride = "";
        }
    }

    /** Rebuild the pinned hex from hue (0-359) / sat (0-1) / light (0-1). */
    function setAccentHsl(hDeg, s01, l01) {
        var hue01 = Math.max(0, Math.min(1, hDeg / 360));
        /* Floor sat/light so a drag from a degenerate (black/gray) seed never
         * writes #000000 — the sliders must always produce a visible colour. */
        var col = Qt.hsla(hue01, Math.max(0.05, Math.min(1, s01)), Math.max(0.05, Math.min(1, l01)), 1);
        Flags.accentOverride = root.rgbHex(col);
    }

    rows: [
        { item: accentRow, kind: "toggle", get: function () { return root.accentCustom; }, set: function (v) { root.setAccentCustom(v); } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "彩"
            title: "ACCENT"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        /**
         * Accent color: an optional user hex that wins over the Light/Dark default,
         * the wallpaper accent and the manual hue for every warm token (glow,
         * verm ramps, flame ink). Turning Custom on seeds from the current scheme
         * accent and unfolds the picker below. The chip in the row previews the
         * live accent either way.
         */
        SettingsRow {
            id: accentRow
            surface: root
            name: "Accent color"
            icon: "sparkles"
            sub: root.accentSub

            Item {
                width: accentChip.width + 10 * root.s + accentToggle.width
                height: 26 * root.s

                Rectangle {
                    id: accentChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20 * root.s
                    height: 20 * root.s
                    radius: 6 * root.s
                    color: root.accentColorValue
                    border.width: 1
                    border.color: Theme.hairSoft
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                LinkToggle {
                    id: accentToggle
                    anchors.left: accentChip.right
                    anchors.leftMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    s: root.s
                    on: root.accentCustom
                    onToggled: root.setAccentCustom(!root.accentCustom)
                }
            }
        }

        /**
         * The accent picker, folded shut unless Custom is on. Hue and saturation
         * are native QtQuick Controls sliders: they recolor live while held
         * (`pressed`) and re-commit on release (`onMoved`) so the final position
         * always lands. The row beneath pairs a live swatch with the hex field
         * for exact entry, and typing keeps both sliders in sync.
         */
        Item {
            id: accentSection
            width: parent.width
            height: root.accentCustom ? accentPanel.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: accentPanel
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
                        id: accentHueSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setAccentHsl(Math.round(accentHueSlider.value * 359), root.accentSat01, root.accentLight01)
                        onMoved: root.setAccentHsl(Math.round(accentHueSlider.value * 359), root.accentSat01, root.accentLight01)
                        Component.onCompleted: accentHueSlider.value = root.accentHue01

                        background: Rectangle {
                            y: accentHueSlider.availableHeight / 2 - 7 * root.s
                            width: accentHueSlider.availableWidth
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
                            x: accentHueSlider.leftPadding + accentHueSlider.visualPosition * (accentHueSlider.availableWidth - width)
                            y: accentHueSlider.availableHeight / 2 - height / 2
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
                        id: accentSatSlider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26 * root.s
                        from: 0
                        to: 1
                        stepSize: 0.005
                        onValueChanged: if (pressed) root.setAccentHsl(root.accentHue01 * 359, accentSatSlider.value, root.accentLight01)
                        onMoved: root.setAccentHsl(root.accentHue01 * 359, accentSatSlider.value, root.accentLight01)
                        Component.onCompleted: accentSatSlider.value = root.accentSat01

                        background: Rectangle {
                            y: accentSatSlider.availableHeight / 2 - 7 * root.s
                            width: accentSatSlider.availableWidth
                            height: 14 * root.s
                            radius: 7 * root.s
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsla(root.accentHue01, 0.0, 0.5, 1) }
                                GradientStop { position: 0.5; color: Qt.hsla(root.accentHue01, 0.5, 0.5, 1) }
                                GradientStop { position: 1.0; color: Qt.hsla(root.accentHue01, 1.0, 0.5, 1) }
                            }
                        }
                        handle: Rectangle {
                            x: accentSatSlider.leftPadding + accentSatSlider.visualPosition * (accentSatSlider.availableWidth - width)
                            y: accentSatSlider.availableHeight / 2 - height / 2
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
                    height: Math.max(34 * root.s, accentHexField.implicitHeight)

                    Rectangle {
                        id: accentPickSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColorValue
                        border.width: 1
                        border.color: Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        id: accentHexHint
                        anchors.left: accentPickSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: Font.DemiBold
                    }

                    TextField {
                        id: accentHexField
                        anchors.left: accentHexHint.right
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
                                Flags.accentOverride = Theme.hexUpper(c);
                                accentHueSlider.value = root.accentHue01;
                                accentSatSlider.value = root.accentSat01;
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
                        anchors.left: accentHexField.left
                        anchors.right: accentHexField.right
                        anchors.top: accentHexField.bottom
                        anchors.topMargin: 3 * root.s
                        height: 1
                        color: Theme.faint
                        opacity: accentHexField.activeFocus ? 0.7 : 0.18
                        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                    }
                }
            }
        }
    }
}