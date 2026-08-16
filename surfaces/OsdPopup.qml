pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"

/**
 * Standalone OSD overlay, fully decoupled from the pill. The pill never morphs
 * for volume/brightness/workspace flashes anymore; this capsule shows itself at
 * its final size, grows in from the screen top like a notch, holds for the
 * flash timeout, then shrinks away. Content stays at fixed geometry the whole
 * time, so the level bars never stretch with the transition.
 */
Item {
    id: popup

    property real s: 1
    property string screenName: ""
    property bool suppressed: false
    property bool expanded: false

    /**
     * 1 when the popup should dock flush to the screen top like the strip bar
     * (squared top corners); 0 for the rounded island capsule. Mirrors the
     * pill's own top-flat rule so the OSD keeps each display mode's silhouette.
     */
    property real topFlat: 0
    Behavior on topFlat { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    readonly property bool active: osd.flashing

    width: osd.desiredW
    height: osd.desiredH
    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    opacity: active ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: active ? Motion.fast : 220; easing.type: Easing.OutCubic } }

    transformOrigin: Item.Top
    scale: active ? 1 : 0.68
    Behavior on scale {
        NumberAnimation {
            duration: active ? Motion.standard : Motion.fast
            easing.type: active ? Easing.OutCubic : Easing.InCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 22 * s
        topLeftRadius: 22 * s * (1 - topFlat)
        topRightRadius: 22 * s * (1 - topFlat)
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, Flags.pillOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, Flags.pillOpacity) }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * s
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: parent.radius * 0.6
            anchors.rightMargin: parent.radius * 0.6
            height: 1
            color: Theme.sheen
        }
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * s
        anchors.leftMargin: 18 * s
        anchors.rightMargin: 18 * s
        anchors.bottomMargin: 12 * s
        s: popup.s
        screenName: popup.screenName
        suppressed: popup.suppressed
        expanded: popup.expanded
    }
}
