pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property real mult: Flags.reduceMotion ? 0.4 : 1
    readonly property int fast:     Math.round(140 * mult)
    readonly property int standard: Math.round(300 * mult)
    readonly property int morph:    Math.round(420 * mult)
    readonly property int shapeshift: Math.round(820 * mult)
    readonly property int glide:    Math.round(260 * mult)
    readonly property int heat:     Math.round(1100 * mult)
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline

    /**
     * Liquid morph curve, cubic-bezier(0.16, 1, 0.3, 1). Front-loaded like an
     * exponential chase but with a long, visible settle tail. Use with
     * easeMorph (BezierSpline).
     */
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13

    /**
     * Per-bar animation styles (Standard / Snap / Float / Bounce). Each bar
     * resolves its own feel through its own flag; shared settings chrome and
     * the lock screen keep the base tokens unchanged.
     */
    function styleScale(style) {
        if (style === "snap") return 0.55;
        if (style === "float") return 1.45;
        return 1; // standard, and bounce — bounce keeps its duration and eases instead
    }
    function styleEase(style) {
        if (style === "snap") return Easing.OutCubic;
        if (style === "float") return Easing.InOutCubic;
        if (style === "bounce") return Easing.OutBack;
        return easeMorph;
    }

    readonly property int pillMorph: Math.round(morph * styleScale(Flags.motionStyle))
    readonly property int pillGlide: Math.round(glide * styleScale(Flags.motionStyle))
    readonly property int pillFast: Math.round(fast * styleScale(Flags.motionStyle))
    readonly property int pillStandard: Math.round(standard * styleScale(Flags.motionStyle))
    readonly property int dockMorph: Math.round(morph * styleScale(Flags.dockMotionStyle))
    readonly property int dockFast: Math.round(fast * styleScale(Flags.dockMotionStyle))
    readonly property int pillEase: styleEase(Flags.motionStyle)
    readonly property int dockEase: styleEase(Flags.dockMotionStyle)

    /** Looping scan/pairing breath pulse. */
    readonly property int pulse: Math.round(420 * mult)
}
