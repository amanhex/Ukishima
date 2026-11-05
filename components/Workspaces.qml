pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Workspace dots for one monitor. No numbers, no icons. Active one is a larger
 * filled vermillion dot; the rest are small and dim, brightening on hover.
 * Clicking a dot activates that workspace.
 *
 * The list comes from [[Wm]], not from a compositor: the Hyprland provider
 * unions that monitor's workspace rules with its live workspaces, the generic
 * provider maps ext-workspace's screen projection. A rule-driven setup (e.g.
 * 1-5 / 6-10 across two screens) still shows every assigned dot, and a dynamic
 * workspace (niri) still appears as soon as the compositor creates it.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: (bars ? 4 : 5) * s
    property real gap: 4 * s
    /**
     * "dots" is the resting bar's clickable strip; "bars" is the status face's
     * static height-coded strip. Same workspace range, no interaction.
     */
    property string variant: "dots"
    readonly property bool bars: variant === "bars"

    readonly property var range: Wm.workspacesFor(screenName)
    readonly property string activeName: Wm.activeWorkspaceName(screenName)

    onRangeChanged: if (hoverIndex >= range.length) hoverIndex = -1

    property int hoverIndex: -1

    readonly property int activeIndex: {
        for (let i = 0; i < range.length; i++)
            if (range[i] && String(range[i].name) === activeName)
                return i;
        return -1;
    }

    /**
     * Centre x of a dot slot from target layout widths (active stick is wider).
     * Uses the animation end values, so a focus marker aimed here lands where
     * the dot settles and doesn't chase the width Behavior.
     */
    function slotCenterX(idx) {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += slotW(i) + gap;
        return x + slotW(idx) / 2;
    }

    /** End width of slot `i`; only the dots variant widens the active one. */
    function slotW(idx) {
        return !bars && idx === activeIndex ? stickW : dotW;
    }

    readonly property point activeDotPoint: {
        void workspaces.range;
        void workspaces.activeName;
        void workspaces.width;
        return Qt.point(slotCenterX(Math.max(0, activeIndex)), height / 2);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData
                required property int index

                readonly property bool isActive: workspaces.activeName.length > 0
                    && String(modelData.name) === workspaces.activeName
                readonly property bool occupied: {
                    if (!workspaces.bars) return false;
                    const wins = Wm.windows;
                    for (let i = 0; i < wins.length; i++) {
                        const w = wins[i];
                        if (w && w.workspace && String(w.workspace.name) === String(modelData.name))
                            return true;
                    }
                    return false;
                }

                Layout.preferredWidth: workspaces.slotW(index)
                Layout.preferredHeight: (workspaces.bars ? 16 : 22) * workspaces.s
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.bars
                        ? (slot.isActive ? 16 : (slot.occupied ? 10 : 9)) * workspaces.s
                        : workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: workspaces.bars
                        ? (slot.isActive ? 1 : (slot.occupied ? 0.5 : 0.18))
                        : (slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.3))
                    Behavior on height { enabled: workspaces.bars; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: area
                    visible: !workspaces.bars
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.activateWorkspace(slot.modelData)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            workspaces.hoverIndex = slot.index;
                        else if (workspaces.hoverIndex === slot.index)
                            workspaces.hoverIndex = -1;
                    }
                }
            }
        }
    }
}
