pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../Singletons"

/**
 * One window in the overview: a live preview positioned and sized to match where
 * that window actually sits, so a tiled workspace reads as a tiled miniature.
 *
 * Ported from Tide Island's `WorkspaceOverviewWindow.qml` (GPL-3.0). The parts
 * that are load-bearing rather than cosmetic, and why:
 *
 *  - **`constraintSize`, not `fillMode`.** ScreencopyView is an `Item`, not an
 *    `Image`, so `fillMode` does not exist on it and assigning it fails to
 *    instantiate the file.
 *  - **Previews only stream while visible.** `live` and `captureSource` are both
 *    gated on the tile being on screen, and `captureSource` drops to `null`
 *    rather than merely going non-live. A grid of live captures is the single
 *    biggest cost in this surface; tiles scrolled or paged out are free.
 *  - **`ClippingRectangle` for the rounded clip.** A plain `Rectangle` clip
 *    ignores `radius` in Qt Quick. A `MultiEffect` mask does clip, but it also
 *    rendered these tiles solid black here — the module's own type is both
 *    available and correct.
 */
Item {
    id: root

    property var toplevel: null
    property var windowData: null
    property var monitorData: null
    property var widgetMonitor: null
    property real scale: 0.18
    property real xOffset: 0
    property real yOffset: 0
    property bool centerIcons: true
    property bool previewEnabled: true
    property bool hovered: false
    property bool pressed: false
    property bool draggingActive: false
    property bool forcePreviewActive: false
    property var positionOverride: null
    property real visibilityOpacity: 1
    property real topLeftRadius: 18
    property real topRightRadius: 18
    property real bottomLeftRadius: 18
    property real bottomRightRadius: 18

    readonly property real widthRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return monitorWidth > 0 ? (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale) : 1;
    }
    readonly property real heightRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return monitorHeight > 0 ? (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale) : 1;
    }

    readonly property real targetWindowWidth: Math.max(52, (windowData && windowData.size ? windowData.size[0] : 240) * scale * widthRatio)
    readonly property real targetWindowHeight: Math.max(38, (windowData && windowData.size ? windowData.size[1] : 140) * scale * heightRatio)

    /**
     * Position of the window's top-left within the workspace cell, with the
     * monitor origin and reserved insets removed. The insets matter: the pill
     * runs in `ExclusionMode.Ignore` and reserves nothing, but a user who has
     * given the bar real exclusive space would otherwise see every preview
     * offset by the bar height.
     */
    readonly property real initX: {
        if (!windowData || !monitorData)
            return xOffset;
        const reserved = monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const position = positionOverride
            ? [positionOverride.x, positionOverride.y]
            : (windowData.at ? windowData.at : [monitorData.x, monitorData.y]);
        return Math.max((position[0] - monitorData.x - reserved[0]) * widthRatio * scale, 0) + xOffset;
    }
    readonly property real initY: {
        if (!windowData || !monitorData)
            return yOffset;
        const reserved = monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const position = positionOverride
            ? [positionOverride.x, positionOverride.y]
            : (windowData.at ? windowData.at : [monitorData.x, monitorData.y]);
        return Math.max((position[1] - monitorData.y - reserved[1]) * heightRatio * scale, 0) + yOffset;
    }

    readonly property string iconLookupName: {
        if (!windowData)
            return "";
        return windowData.class || windowData.initialClass || windowData.title || "";
    }
    readonly property bool compactMode: Math.min(targetWindowWidth, targetWindowHeight) < 120
    readonly property string iconPath: compactMode
        ? Quickshell.iconPath(String(iconLookupName).toLowerCase(), "image-missing")
        : ""

    readonly property real baseOpacity: !windowData
        ? 0
        : (widgetMonitor && windowData.monitor === widgetMonitor.id ? 1 : 0.46)

    /**
     * The gate that keeps this cheap. A tile only captures while it is actually
     * on screen; `forcePreviewActive` keeps the dragged tile and the settling
     * one live, since both move over cells that are visible.
     */
    readonly property bool previewActive: previewEnabled && !!toplevel && (forcePreviewActive || (visible && opacity > 0))

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: baseOpacity * visibilityOpacity
    z: windowData && windowData.fullscreen ? 2 : 1

    Behavior on x {
        enabled: !root.draggingActive
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: !root.draggingActive
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        color: "transparent"
        antialiasing: true
        contentUnderBorder: true
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.width: 1
        border.color: root.hovered ? "#77ffffff" : "#33ffffff"

        ScreencopyView {
            id: shot
            anchors.fill: parent
            captureSource: root.previewActive ? root.toplevel : null
            constraintSize: Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
            live: root.previewActive
        }

        /**
         * Fallback. Shown when there is no capture at all — no handle, or the
         * compositor declined to export — and when the tile is too small for a
         * preview to read as anything.
         */
        Item {
            anchors.fill: parent
            visible: !root.previewActive || !shot.hasContent

            Image {
                id: appIcon
                property bool iconLoadFailed: false

                anchors.centerIn: parent
                width: Math.max(14, Math.min(root.width, root.height) * 0.42)
                height: width
                sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                mipmap: true
                smooth: true
                opacity: 0.9
                source: !iconLoadFailed ? root.iconPath : ""

                onStatusChanged: {
                    if (status === Image.Error)
                        iconLoadFailed = true;
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.draggingActive
                ? "#14ffffff"
                : (root.pressed
                    ? "#26000000"
                    : (root.hovered ? "#10ffffff" : "transparent"))
        }
    }
}
