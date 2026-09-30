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
    color: MsTheme.m3onSurface
    font.family: MsTheme.bodyFamily
    font.pointSize: MsTheme.bodySmall

    Behavior on color {
        ColorAnimation {
            duration: MsTheme.durSlowEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: MsTheme.curveSlowEffects
        }

    }

    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            MsAnim {
                target: root
                property: "opacity"
                to: 0
                type: MsAnim.FastEffects
            }

            PropertyAction {
            }

            MsAnim {
                target: root
                property: "opacity"
                to: 1
                type: MsAnim.DefaultEffects
            }

        }

    }

}
