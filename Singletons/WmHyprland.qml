pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/**
 * Hyprland provider. Wraps the hyprctl snapshots and Hyprland models the shell
 * already used, normalized to the interface Wm.qml exposes. Kept alive only
 * when a Hyprland session is present; the generic provider carries every other
 * compositor.
 */
Singleton {
    id: root

    readonly property bool available: {
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return sig && sig.length > 0;
    }

    readonly property string compositor: "hyprland"

    readonly property var caps: ({
        workspaceRules: true,
        specialWorkspaces: true,
        minimizable: true,
        keyboardLayout: true,
        nightLight: true,
        gameModeStrip: true,
        globalShortcuts: true,
        lock: ["hyprlock", "quickshell"]
    })

    /** Raw hyprctl snapshots. The pill has always read these rather than the
     *  Quickshell models, which stay empty until the first switch and left the
     *  workspace dots blank on a fresh launch. */
    property var snapMons: []
    property var snapWss: []
    property int bootTries: 0

    readonly property var windows: {
        const out = [];
        const tls = Hyprland.toplevels.values;
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t)
                continue;
            const cls = (t.lastIpcObject && t.lastIpcObject.class)
                ? String(t.lastIpcObject.class)
                : (t.wayland && t.wayland.appId ? String(t.wayland.appId) : "");
            const screens = [];
            if (t.screens) {
                for (let s = 0; s < t.screens.length; s++)
                    if (t.screens[s])
                        screens.push(String(t.screens[s].name));
            }
            out.push({
                id: t.address || "",
                address: t.address || "",
                handle: t.address || "",
                appId: cls,
                title: t.title || "",
                active: !!t.activated,
                activated: !!t.activated,
                workspace: t.workspace ? { name: String(t.workspace.name) } : null,
                minimized: !!(t.workspace && t.workspace.name === "special:minimized"),
                fullscreen: !!(t.lastIpcObject && t.lastIpcObject.fullscreen),
                lastIpcObject: { class: cls },
                wayland: { appId: cls },
                screens: screens,
                raw: t
            });
        }
        return out;
    }

    function focusedScreen() {
        for (let i = 0; i < root.snapMons.length; i++)
            if (root.snapMons[i] && root.snapMons[i].focused)
                return String(root.snapMons[i].name);
        return Hyprland.focusedMonitor && Hyprland.focusedMonitor.name
            ? String(Hyprland.focusedMonitor.name) : "";
    }

    function monitorSnap(name) {
        for (let i = 0; i < root.snapMons.length; i++)
            if (root.snapMons[i] && root.snapMons[i].name === name)
                return root.snapMons[i];
        return null;
    }

    function activeWorkspaceName(output) {
        const m = root.monitorSnap(output);
        if (m && m.activeWorkspace && m.activeWorkspace.name)
            return String(m.activeWorkspace.name);
        const fm = Hyprland.focusedMonitor;
        if (fm && fm.name === output && fm.activeWorkspace)
            return String(fm.activeWorkspace.name);
        return "";
    }

    function specialWorkspaceName(output) {
        const m = root.monitorSnap(output);
        return (m && m.specialWorkspace && m.specialWorkspace.name)
            ? String(m.specialWorkspace.name) : "";
    }

    function fullscreenOn(output) {
        const m = root.monitorSnap(output);
        if (!m || !m.activeWorkspace)
            return false;
        if (m.activeWorkspace.hasfullscreen)
            return true;
        const list = root.windows;
        const wsName = root.activeWorkspaceName(output);
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || !w.fullscreen)
                continue;
            if (w.screens && w.screens.indexOf(output) >= 0)
                return true;
            if (wsName && w.workspace && w.workspace.name === wsName)
                return true;
        }
        return false;
    }

    /** Workspace list per output, invalidated only when the set or order
     *  changes. Active state is queried separately so a focus change does not
     *  recreate the strip's delegates or restart its width animation. */
    property var wsCache: ({})

    /**
     * Workspace slots for one output: the workspace rules assigned to it plus
     * every live workspace it owns. Rules make a split setup (1-5 / 6-10) show
     * all its dots before the workspaces have been visited.
     */
    function workspacesFor(output) {
        if (!root.available)
            return [];
        const ruled = Workspacerules.byMonitor[output];
        const out = [];
        const seen = ({});
        let sig = output + "|";
        if (ruled && ruled.length) {
            for (let r = 0; r < ruled.length; r++) {
                sig += "r" + ruled[r] + ",";
                if (!seen[ruled[r]]) {
                    seen[ruled[r]] = true;
                    out.push(ruled[r]);
                }
            }
        }
        for (let i = 0; i < root.snapWss.length; i++) {
            const w = root.snapWss[i];
            if (w && w.id >= 1 && w.monitor === output && !seen[w.id]) {
                seen[w.id] = true;
                sig += "w" + w.id + ",";
                out.push(w.id);
            }
        }
        const cached = root.wsCache[output];
        if (cached && cached.sig === sig)
            return cached.list;

        out.sort(function (x, y) { return x - y; });
        const list = [];
        for (let n = 0; n < out.length; n++) {
            list.push({
                id: out[n],
                name: String(out[n])
            });
        }
        root.wsCache[output] = { sig: sig, list: list };
        return list;
    }

    function activateWorkspace(ws) {
        if (!ws || !ws.name)
            return;
        const name = String(ws.name);
        const lit = /^-?\d+$/.test(name) ? name : JSON.stringify(name);
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + lit + " })");
    }

    function focusWindow(win) {
        if (!win)
            return;
        let addr = String(win.address || win.id || "");
        if (!addr)
            return;
        if (addr.indexOf("0x") !== 0)
            addr = "0x" + addr;
        // Hyprland's focuswindow warps the cursor; toggling no_warps around
        // this one dispatch keeps a dock click from teleporting the pointer.
        Quickshell.execDetached(["sh", "-c",
            "hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1; " +
            "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + addr + "\" })' >/dev/null 2>&1; " +
            "hyprctl eval 'hl.config({ cursor = { no_warps = false } })' >/dev/null 2>&1",
            "sh"]);
    }

    function minimizeWindow(addr) {
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + addr + '" })');
    }

    function restoreWindow(arg) {
        const p = arg.split("|");
        if (p.length < 2 || p[0].length === 0)
            return;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + p[1] + '", window = "address:' + p[0] + '" })');
    }

    function logout() {
        Hyprland.dispatch("hl.dsp.exit()");
    }

    function refresh() {
        if (!root.available)
            return;
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        proc.running = true;
    }

    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        enabled: root.available
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                Workspacerules.refresh();
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.available && root.snapMons.length === 0 && root.bootTries < 8
        onTriggered: {
            root.bootTries += 1;
            root.refresh();
        }
    }

    Process {
        id: proc
        running: false
        command: ["sh", "-c", "hyprctl monitors -j; printf '@@@'; hyprctl workspaces -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text;
                const sep = text.indexOf("@@@");
                try {
                    root.snapMons = JSON.parse(sep >= 0 ? text.slice(0, sep) : "[]");
                } catch (e) {
                    root.snapMons = [];
                }
                try {
                    root.snapWss = JSON.parse(sep >= 0 ? text.slice(sep + 3) : "[]");
                } catch (e) {
                    root.snapWss = [];
                }
            }
        }
    }

    Component.onCompleted: if (root.available) {
        root.refresh();
        Workspacerules.refresh();
    }
}
