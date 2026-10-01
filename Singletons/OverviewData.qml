import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

/**
 * 概 Workspace/window data for the overview — Tide Island's `HyprlandData`,
 * re-pointed at this shell's conventions.
 *
 * Read straight from `hyprctl` rather than the Quickshell Hyprland models, for
 * the same reason components/Workspaces.qml does (see its header): on a fresh
 * launch `Hyprland.workspaces.values` stays empty, workspace entries carry a
 * null monitor, and `focusedWorkspace` is null, so anything bound to those
 * renders blank until the first workspace switch. A raw fetch is deterministic
 * from the first frame, and the overview cannot afford to open onto an empty
 * grid.
 *
 * Exposes the shape the ported layer expects:
 *   `ready`             — a snapshot has landed
 *   `monitors`          — id, name, x, y, width, height, scale, transform, reserved
 *   `workspaces`        — id, name, monitor (name), windows
 *   `windowByAddress`   — lowercase `0x…` address → window record
 *   `activeWorkspace`   — the focused monitor's active workspace name
 *
 * Note the one genuinely counter-intuitive field: `workspaces[].monitor` is the
 * monitor **name** ("eDP-1") while `clients[].monitor` is a numeric **id** (0).
 * The two disagree in `hyprctl` itself. Getting this backwards matches nothing
 * and silently empties the grid.
 */
Singleton {
    id: root

    property var monitors: []
    property var workspaces: []
    property var windowByAddress: ({
    })
    property string activeWorkspace: ""
    property bool ready: false
    /**
     * The first snapshot runs on load, but a slow compositor reply can still
     * beat it to the first frame — and the overview is opened by a keybind, so
     * an empty first frame is very visible. Poll briefly until data lands.
     */
    property int bootTries: 0

    //* Windows on one monitor, ascending by workspace id.
    function forMonitor(name) {
        var out = [];
        for (var i = 0; i < root.workspaces.length; i++) {
            var w = root.workspaces[i];
            if (w && w.monitor === name)
                out.push(w);

        }
        return out;
    }

    function refresh() {
        proc.running = true;
    }

    function iconFor(cls) {
        if (!cls || cls.length === 0)
            return "";

        return Quickshell.iconPath(cls, "application-x-executable");
    }

    Component.onCompleted: refresh()

    Timer {
        id: bootPoll

        interval: 200
        repeat: true
        running: true
        onTriggered: {
            root.refresh();
            root.bootTries += 1;
            if (root.ready || root.bootTries >= 10)
                bootPoll.running = false;

        }
    }

    /**
     * Window-level events matter as much as workspace ones here: the grid is
     * mostly windows, so a bare workspace watch would leave a cell stale after
     * opening or closing an app — the common case, not the rare one.
     */
    Connections {
        function onRawEvent(event) {
            var n = event.name;
            if (n === "workspace" || n === "workspacev2" || n === "createworkspace" || n === "destroyworkspace" || n === "moveworkspace" || n === "renameworkspace" || n === "focusedmon" || n === "focusedmonv2" || n === "monitoradded" || n === "monitorremoved" || n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "activewindow" || n === "fullscreen" || n === "changefloatinglayout")
                root.refresh();

        }

        target: Hyprland
    }

    /**
     * Three queries in one shell invocation, separated by `@@@` — the pattern
     * components/Workspaces.qml uses. Three separate Processes would be three
     * spawns racing to half-fill the model, and the grid would render a frame of
     * workspace data beside window data from a different instant.
     */
    Process {
        id: proc

        command: ["sh", "-c", "hyprctl monitors -j; printf '@@@'; hyprctl workspaces -j; printf '@@@'; hyprctl clients -j"]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("@@@");
                var mons = [];
                var wss = [];
                var clients = [];
                try {
                    mons = JSON.parse(parts.length > 0 ? parts[0] : "[]");
                } catch (e) {
                }
                try {
                    wss = JSON.parse(parts.length > 1 ? parts[1] : "[]");
                } catch (e) {
                }
                try {
                    clients = JSON.parse(parts.length > 2 ? parts[2] : "[]");
                } catch (e) {
                }
                var monOut = [];
                var activeByMon = {
                };
                for (var m = 0; m < mons.length; m++) {
                    var mo = mons[m];
                    if (!mo)
                        continue;

                    if (mo.name && mo.activeWorkspace)
                        activeByMon[mo.name] = String(mo.activeWorkspace.name);

                    //* `transform` is a bitmask; bit 0 set means the output is
                    //* rotated, so logical width/height are swapped.
                    var rot = (mo.transform || 0) & 1;
                    monOut.push({
                        "id": mo.id,
                        "name": mo.name || "",
                        "x": mo.x || 0,
                        "y": mo.y || 0,
                        "width": rot ? (mo.height || 0) : (mo.width || 0),
                        "height": rot ? (mo.width || 0) : (mo.height || 0),
                        "scale": mo.scale || 1,
                        "transform": mo.transform || 0,
                        "reserved": mo.reserved || [0, 0, 0, 0]
                    });
                }
                var byAddr = {
                };
                var byWs = {
                };
                for (var c = 0; c < clients.length; c++) {
                    var cl = clients[c];
                    if (!cl || !cl.workspace)
                        continue;

                    var wid = cl.workspace.id;
                    //* A client on no workspace carries id -99; it belongs to no
                    //* cell, so it is dropped rather than filed under -99.
                    if (wid === undefined || wid === null || wid < 0)
                        continue;

                    var addr = String(cl.address || "").toLowerCase();
                    var rec = {
                        "address": cl.address || "",
                        "class": cl.class || "",
                        "initialClass": cl.initialClass || "",
                        "title": cl.title || "",
                        "at": cl.at || [0, 0],
                        "size": cl.size || [0, 0],
                        "workspace": cl.workspace,
                        "floating": !!cl.floating,
                        "fullscreen": (cl.fullscreen || 0) !== 0,
                        "monitor": cl.monitor
                    };
                    byAddr[addr] = rec;
                    if (!byWs[wid])
                        byWs[wid] = [];

                    byWs[wid].push(rec);
                }
                var wsOut = [];
                for (var w = 0; w < wss.length; w++) {
                    //* Name, not id — see the header.
                    //* Hyprland prefixes special workspaces with "special:".

                    var ws = wss[w];
                    if (!ws || ws.id === undefined)
                        continue;

                    var wname = String(ws.name === undefined ? ws.id : ws.name);
                    var wmon = ws.monitor || "";
                    wsOut.push({
                        "id": ws.id,
                        "name": wname,
                        "monitor": wmon,
                        "active": activeByMon[wmon] === wname,
                        "special": wname.indexOf("special") === 0,
                        "windows": byWs[ws.id] || []
                    });
                }
                wsOut.sort(function(a, b) {
                    return a.id - b.id;
                });
                root.monitors = monOut;
                root.workspaces = wsOut;
                root.windowByAddress = byAddr;
                root.activeWorkspace = activeByMon[mons.length > 0 ? (mons[0].name || "") : ""] || "";
                root.ready = wsOut.length > 0;
            }
        }

    }

}
