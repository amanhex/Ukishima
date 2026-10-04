import QtQuick

/**
 * Vendored midnight-shell StyledText (components/StyledText.qml): text with
 * animated color and optional animated text swaps (used by the password
 * placeholder).
 */
Text {
    id: root

    property bool animate: false

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: PolTheme.m3onSurface
    font.family: PolTheme.bodyFamily
    font.pointSize: PolTheme.bodySmall

    Behavior on color {
        ColorAnimation {
            duration: PolTheme.durSlowEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: PolTheme.curveSlowEffects
        }

    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            PolAnim {
                target: root
                property: "opacity"
                to: 0
                type: PolAnim.FastEffects
            }

            PropertyAction {
            }

            PolAnim {
                target: root
                property: "opacity"
                to: 1
                type: PolAnim.DefaultEffects
            }

        }

    }

}
