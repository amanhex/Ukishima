import QtQuick
import Quickshell
pragma Singleton

/**
 * Vendored midnight-shell Tokens + Colours, exact default values taken from
 * midnight-shell's plugin/src/Caelestia/Config (tokens.hpp,
 * appearanceconfig.hpp) and services/Colours.qml.
 *
 * Palette is the fixed dark theme: hardcoded hex, deliberately NOT
 * fed by Dyn/matugen or Theme mode so the polkit dialog keeps its curated
 * identity on any wallpaper. layer() is the identity, matching midnight's
 * opaque defaults (transparency disabled -> Colours.layer returns unchanged).
 *
 * The Pol* prefix (PolTheme, PolAnim, PolIcon, PolText) marks the vendored
 * midnight-shell/caelestia stand-ins, so a reader does not mistake them for
 * real caelestia imports — they carry no external dependency.
 */
Singleton {
    id: root

    // Appearance scale (Tokens.rounding.scale / anim.durations.scale).
    readonly property real scale: 1
    // Rounding (Tokens.rounding).
    readonly property int roundingExtraSmall: 4
    readonly property int roundingSmall: 8
    readonly property int roundingMedium: 12
    readonly property int roundingLarge: 16
    readonly property int roundingLargeIncreased: 20
    readonly property int roundingExtraLarge: 28
    readonly property int roundingFull: 9999
    // Spacing / padding (Tokens.spacing / Tokens.padding).
    readonly property int spacingExtraSmall: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingExtraLarge: 28
    readonly property int paddingExtraSmall: 4
    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 12
    readonly property int paddingLarge: 16
    readonly property int paddingExtraLarge: 28
    // Font sizes (Tokens.fontSize + FontStyle defaults).
    readonly property int bodyLarge: 16
    readonly property int bodyMedium: 14
    readonly property int bodySmall: 12
    readonly property int titleLarge: 22
    readonly property int monoMedium: 14
    readonly property int iconExtraLarge: 36 // 48 / 1.33
    readonly property int iconLarge: 24 // 32 / 1.33
    readonly property int iconMedium: 18 // 24 / 1.33
    readonly property int iconSmall: 15 // 20 / 1.33
    readonly property string bodyFamily: Qt.fontFamilies().indexOf("GoogleSansFlex") >= 0 ? "GoogleSansFlex" : "Rubik"
    readonly property string monoFamily: "CaskaydiaCove NF"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property int iconGrade: -25
    // Durations (Tokens.anim.durations).
    readonly property int durSmall: 200
    readonly property int durNormal: 400
    readonly property int durLarge: 600
    readonly property int durExtraLarge: 1000
    readonly property int durFastSpatial: 350
    readonly property int durDefaultSpatial: 500
    readonly property int durSlowSpatial: 650
    readonly property int durFastEffects: 150
    readonly property int durDefaultEffects: 200
    readonly property int durSlowEffects: 300
    // Curves (Tokens.anim).
    readonly property var curveEmphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    // Sizes (Tokens.sizes.lock).
    readonly property int lockCenterWidth: 600
    // Palette (Colours.palette m3 slots). Fixed dark values taken from the
    // Theme.qml dark branch, hardcoded so Dyn/matugen never retints this.
    readonly property color m3surface: "#171717"
    readonly property color m3surfaceContainer: "#141414"
    readonly property color m3surfaceContainerHigh: "#242424"
    readonly property color m3onSurface: "#ffffff"
    readonly property color m3onSurfaceVariant: "#8c8c8c"
    readonly property color m3outline: "#6a6a6a"
    readonly property color m3secondary: "#a8a8a8"
    readonly property color m3primary: "#e0563b"
    readonly property color m3error: "#ffb4ab"
    readonly property color m3shadow: "#000000"

    function layer(c: color) : color {
        return c;
    }

}
