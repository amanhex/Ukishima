pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"
import "../components"

/**
 * Standalone OSD overlay, fully decoupled from the pill. The pill never morphs
 * for volume/brightness/workspace flashes; this compact pill drops in below the
 * bar, holds for the flash timeout, then fades away. Content stays at fixed
 * geometry the whole time, so the level bar never stretches.
 */
Item {
    id: popup

    property real s: 1
    property string screenName: ""
    property bool suppressed: false
    property bool expanded: false
    /** Waybar mode draws workspaces itself; suppress its redundant flash. */
    property bool workspaceFlash: true

    readonly property bool active: osd.flashing

    width: osd.desiredW
    height: osd.desiredH
    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    opacity: active ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: active ? Motion.fast : 220; easing.type: Easing.OutCubic } }

    transformOrigin: Item.Center
    scale: active ? 1 : 0.9
    Behavior on scale {
        NumberAnimation {
            duration: active ? Motion.standard : Motion.fast
            easing.type: active ? Easing.OutCubic : Easing.InCubic
        }
    }

    /**
     * The shell: the same material as the bar, a full-height capsule with a
     * soft veil and a drop shadow so it reads as a floating overlay.
     */
    LiquidGlass {
        id: glass
        anchors.fill: parent
        radius: height / 2
        style: "regular"
        legacyOpacity: Flags.pillOpacity
        accent: 0.08
        veil: 0.10
        sheenScale: 1.1
        borderColor: Theme.border
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * s
        }
    }

    Osd {
        id: osd
        anchors.fill: parent
        s: popup.s
        screenName: popup.screenName
        suppressed: popup.suppressed
        expanded: popup.expanded
        workspaceFlash: popup.workspaceFlash
    }
}