import QtQuick

/**
 * Vendored midnight-shell MaterialIcon (components/MaterialIcon.qml).
 * Upstream builds the font through the Tokens icon builders (family
 * "Material Symbols Rounded", FILL axis, GRAD -25 in dark mode); the
 * call sites are adapted to plain size/weight/fill props with the same
 * rendered result.
 */
Text {
    id: root

    property real fill: 0
    property int grade: PolTheme.iconGrade
    property real iconSize: PolTheme.iconMedium
    property int iconWeight: Font.Normal

    renderType: Text.NativeRendering
    font.family: PolTheme.iconFamily
    font.pointSize: iconSize
    font.weight: iconWeight
    font.variableAxes: ({
        "FILL": fill,
        "GRAD": grade,
        "opsz": iconSize
    })
}
