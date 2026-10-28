pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.WindowManager
import Quickshell.Io

/**
 * Protocol-generic provider: ext-workspace-v1 for workspaces and
 * wlr-foreign-toplevel-management for windows. No compositor names here
 * except the niri IPC fallback for activating a workspace when the protocol
 * request is not implemented; everything else is the same on any compositor
 * that advertises those two protocols.
 */
Singleton {
    id: root

    readonly property bool available: true

    readonly property string compositor: {
        const requested = Quickshell.env("UKISHIMA_WM");
        const niri = Quickshell.env("NIRI_SOCKET");
        return requested === "niri" || (niri && niri.length > 0) ? "niri" : "generic";
    }

    readonly property var caps: ({
        workspaceRules: false,
        specialWorkspaces: false,
        minimizable: false,
        keyboardLayout: true,
        nightLight: false,
        gameModeStrip: false,
        windowSnap: false,
        globalShortcuts: false,
        lock: root.compositor === "niri"
            ? ["quickshell", "swaylock"] : ["quickshell"]
    })

    property var keyboardLayoutNames: []
    property string keyboardLayoutName: ""

    function setKeyboardLayout(index) {
        if (!Array.isArray(keyboardLayoutNames) ||
            !Number.isInteger(index) || index < 0 ||
            index >= keyboardLayoutNames.length)
            return;
        const name = keyboardLayoutNames[index];
        if (typeof name === "string")
            keyboardLayoutName = name;
    }

    function handleKeyboardEvent(line) {
        try {
            const event = JSON.parse(line);
            if (event.KeyboardLayoutsChanged &&
                event.KeyboardLayoutsChanged.keyboard_layouts) {
                const layouts = event.KeyboardLayoutsChanged.keyboard_layouts;
                if (!Array.isArray(layouts.names))
                    return;
                keyboardLayoutNames = layouts.names;
                setKeyboardLayout(layouts.current_idx);
            } else if (event.KeyboardLayoutSwitched) {
                setKeyboardLayout(event.KeyboardLayoutSwitched.idx);
            }
        } catch (e) {
            console.warn("WmGeneric: malformed niri keyboard event:", e);
        }
    }

    Process {
        running: root.compositor === "niri"
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: (line) => root.handleKeyboardEvent(line)
        }
    }

    readonly property var windows: {
        const out = [];
        const tls = ToplevelManager.toplevels.values;
        const seen = ({});
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (!t)
                continue;
            const cls = String(t.appId || "");
            const title = String(t.title || "");
            const base = cls + "|" + title;
            seen[base] = (seen[base] || 0) + 1;
            const key = base + "#" + seen[base];
            const screens = [];
            if (t.screens) {
                for (let s = 0; s < t.screens.length; s++)
                    if (t.screens[s])
                        screens.push(String(t.screens[s].name));
            }
            out.push({
                id: key,
                address: "",
                handle: key,
                appId: cls,
                title: title,
                active: !!t.activated,
                activated: !!t.activated,
                // Foreign-toplevel has no workspace concept; the dock only uses
                // this to prefer the current workspace, so an empty name is
                // enough to keep it on its first-seen fallback ordering.
                workspace: { name: "" },
                minimized: !!t.minimized,
                fullscreen: !!t.fullscreen,
                lastIpcObject: { class: cls },
                wayland: { appId: cls },
                screens: screens,
                raw: t
            });
        }
        return out;
    }

    function focusedScreen() {
        const t = ToplevelManager.activeToplevel;
        const own = t && t.screens && t.screens.length > 0 ? t.screens[0] : null;
        if (own && own.name)
            return String(own.name);
        const s = Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return s && s.name ? String(s.name) : "";
    }

    function screenFor(output) {
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i] && Quickshell.screens[i].name === output)
                return Quickshell.screens[i];
        return null;
    }

    function coordOf(ws) {
        return (ws && ws.coordinates && ws.coordinates.length) ? ws.coordinates[0] : 0;
    }

    /** Workspace list per output, keyed by the set/order only; the active
     *  workspace is a separate query so focus changes don't rebuild dots. */
    property var wsCache: ({})

    /** Workspaces on one output, from the protocol's screen projection. */
    function workspacesFor(output) {
        const screen = root.screenFor(output);
        if (!screen)
            return [];

        let sets = [];
        try {
            const proj = WindowManager.screenProjection(screen);
            sets = proj ? proj.windowsets : [];
        } catch (e) {
            sets = [];
        }

        if (!sets || sets.length === 0) {
            // Older/partial implementations do not return the internal screen
            // projection; fall back to the workspace's own projection.
            sets = [];
            const all = WindowManager.windowsets;
            for (let i = 0; i < all.length; i++) {
                const p = all[i] ? all[i].projection : null;
                if (!p || !p.screens)
                    continue;
                for (let s = 0; s < p.screens.length; s++) {
                    if (p.screens[s] && p.screens[s].name === output) {
                        sets.push(all[i]);
                        break;
                    }
                }
            }
        }

        const out = [];
        let sig = output + "|";
        for (let i = 0; i < sets.length; i++) {
            const ws = sets[i];
            if (!ws || ws.shouldDisplay === false)
                continue;
            const coord = root.coordOf(ws);
            const name = ws.name && String(ws.name).length > 0
                ? String(ws.name) : String(coord);
            sig += "w" + ws.id + ":" + name + ":" + coord + ",";
            out.push({
                id: String(ws.id),
                name: name,
                coord: coord,
                raw: ws
            });
        }
        const cached = root.wsCache[output];
        if (cached && cached.sig === sig)
            return cached.list;

        out.sort(function (a, b) {
            if (a.coord !== b.coord)
                return a.coord - b.coord;
            return String(a.name).localeCompare(String(b.name));
        });
        root.wsCache[output] = { sig: sig, list: out };
        return out;
    }

    function activateWorkspace(ws) {
        if (!ws)
            return;
        if (ws.raw && ws.raw.canActivate) {
            ws.raw.activate();
            return;
        }
        if (root.compositor === "niri")
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(ws.name)]);
    }

    function activeWorkspaceName(output) {
        const list = root.workspacesFor(output);
        for (let i = 0; i < list.length; i++)
            if (list[i].raw && list[i].raw.active)
                return list[i].name;
        return "";
    }

    function specialWorkspaceName(output) {
        return "";
    }

    function fullscreenOn(output) {
        const list = root.windows;
        const activeWs = root.activeWorkspaceName(output);
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w.fullscreen || w.screens.indexOf(output) < 0)
                continue;
            if (w.active)
                return true;
            if (activeWs && w.workspace && w.workspace.name === activeWs)
                return true;
            if (!activeWs)
                return true;
        }
        return false;
    }

    function focusWindow(win) {
        if (!win)
            return;
        if (win.raw && win.raw.activate)
            win.raw.activate();
    }

    function minimizeWindow(addr) {
        // No generic minimize request in foreign-toplevel; capability-gated.
    }

    function restoreWindow(arg) {
        // No generic special-workspace stash; capability-gated.
    }

    function logout() {
        if (root.compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "action", "quit"]);
            return;
        }
        const user = Quickshell.env("USER");
        if (user)
            Quickshell.execDetached(["loginctl", "terminate-user", user]);
    }

    function refresh() {
        // Protocol models are live; nothing to pull.
    }
}
