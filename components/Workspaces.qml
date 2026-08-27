pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import "../Singletons"

/**
 * Workspace dots for one monitor. No numbers, no icons. Active one is a larger
 * filled vermillion dot; the rest are small and dim, brightening on hover.
 * Clicking a dot focuses that workspace (Hyprland workspace dispatcher). Active
 * marker tracks the monitor's live active workspace name.
 *
 * The dot range unions this monitor's workspace rules ([[Workspacerules]]) with
 * the workspaces Hyprland currently has on it, so a rule-driven setup (e.g.
 * monitors.lua splitting 1-5 / 6-10 across two screens) always shows every
 * assigned dot while a workspace outside the rules (r+1 past the last ruled
 * one) still appears instead of vanishing from the strip.
 *
 * The workspace list and active workspace are read straight from hyprctl
 * (monitors -j / workspaces -j) rather than the Quickshell Hyprland models:
 * on a fresh launch `Hyprland.monitors.values` stays empty, workspace entries
 * carry a null monitor, and `focusedWorkspace` is null — so the dots would
 * only appear after the first switch re-populates the models. A raw hyprctl
 * fetch is deterministic from the first frame and matches the pattern
 * [[Workspacerules]] already uses for the rule map.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    /**
     * The dot range and active marker are plain properties, recomputed
     * imperatively by rebuild() from the last hyprctl snapshot rather than
     * chained computed bindings. A switch onto an already-created workspace
     * only changes the active workspace — the list itself stays untouched —
     * so a computed binding could be left empty or stale, which is the "dots
     * missing until the next switch" glitch. rebuild always includes this
     * monitor's active workspace, so the strip never sits empty once the
     * monitor's data is known.
     */
    property var range: []
    property string activeName: ""

    property string activeWs: ""
    property var wsList: []

    function refreshData() {
        proc.running = true;
    }

    function rebuild() {
        var out = [];
        var seen = ({});
        var ruled = Workspacerules.byMonitor[screenName];
        if (ruled && ruled.length) {
            for (var r = 0; r < ruled.length; r++) {
                if (!seen[ruled[r]]) {
                    seen[ruled[r]] = true;
                    out.push(ruled[r]);
                }
            }
        }

        var wss = workspaces.wsList;
        for (var i = 0; i < wss.length; i++) {
            var w = wss[i];
            if (w && w.id >= 1 && w.monitor === screenName && !seen[w.id]) {
                seen[w.id] = true;
                out.push(w.id);
            }
        }
        var a = parseInt(workspaces.activeWs);
        if (a >= 1 && !seen[a])
            out.push(a);
        out.sort(function (x, y) { return x - y; });
        activeName = workspaces.activeWs;
        if (!rangesEqual(range, out))
            range = out;
        if (hoverIndex >= range.length)
            hoverIndex = -1;
    }

    function rangesEqual(a, b) {
        if (a.length !== b.length)
            return false;
        for (var i = 0; i < a.length; i++)
            if (a[i] !== b[i])
                return false;
        return true;
    }

    property int hoverIndex: -1

    readonly property int activeIndex: range.indexOf(parseInt(activeName))

    /**
     * Centre x of a dot slot from target layout widths (active stick is wider).
     * Uses the animation end values, so a focus marker aimed here lands where
     * the dot settles and doesn't chase the width Behavior.
     */
    function slotCenterX(idx) {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += (i === activeIndex ? stickW : dotW) + gap;
        return x + (idx === activeIndex ? stickW : dotW) / 2;
    }

    readonly property point activeDotPoint: {
        void workspaces.activeName;
        void workspaces.width;
        return Qt.point(slotCenterX(Math.max(0, activeIndex)), height / 2);
    }

    property int bootTries: 0

    /**
     * The first hyprctl fetch runs on load, but a slow compositor reply could
     * still beat us to the first frame. Poll briefly until a snapshot lands
     * (or give up after the window), then rely on events from there on.
     */
    Timer {
        id: bootPoll
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            workspaces.refreshData();
            workspaces.bootTries += 1;
            if (workspaces.wsList.length > 0 || workspaces.bootTries >= 8)
                bootPoll.running = false;
        }
    }

    Component.onCompleted: refreshData()
    onScreenNameChanged: refreshData()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "workspace" || n === "workspacev2"
                || n === "createworkspace" || n === "destroyworkspace"
                || n === "moveworkspace" || n === "renameworkspace"
                || n === "focusedmon" || n === "focusedmonv2"
                || n === "monitoradded" || n === "monitorremoved")
                workspaces.refreshData();
        }
    }

    Connections {
        target: Workspacerules
        function onByMonitorChanged() { workspaces.rebuild() }
    }

    Process {
        id: proc
        command: ["sh", "-c", "hyprctl monitors -j; printf '@@@'; hyprctl workspaces -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text;
                var sep = text.indexOf("@@@");
                var monJson = sep >= 0 ? text.slice(0, sep) : "[]";
                var wsJson = sep >= 0 ? text.slice(sep + 3) : text;
                var act = "";
                try {
                    var mons = JSON.parse(monJson);
                    for (var m = 0; m < mons.length; m++) {
                        if (mons[m] && mons[m].name === workspaces.screenName && mons[m].activeWorkspace)
                            act = String(mons[m].activeWorkspace.name);
                    }
                } catch (e) { }
                var list = [];
                try {
                    var arr = JSON.parse(wsJson);
                    for (var w = 0; w < arr.length; w++)
                        list.push({ id: arr[w].id, monitor: arr[w].monitor || "" });
                } catch (e) { }
                workspaces.activeWs = act;
                workspaces.wsList = list;
                workspaces.rebuild();
            }
        }
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

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName

                Layout.preferredWidth: slot.isActive ? workspaces.stickW : workspaces.dotW
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + slot.wsName + " })")
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
