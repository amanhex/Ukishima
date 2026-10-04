pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "components"
import "Singletons"

/**
 * 概 Workspace overview — host scope.
 *
 * Holds the open state and mounts one `OverviewWindow` per screen. Modelled on
 * `Polkit.qml`, which is the other thing in this shell that is a full-screen
 * overlay rather than a pill surface: same `Variants` over `Quickshell.screens`,
 * same "only the focused monitor shows it" guard.
 *
 * **No `IpcHandler` here on purpose.** `shell.qml` already owns
 * `IpcHandler { target: "ukishima" }` with every surface entry point, and two
 * handlers sharing a target collide: the second registration replaces the first
 * rather than merging with it. An `IpcHandler` in this file took the target and
 * left `shell.qml`'s twenty-two functions — every other surface's bind —
 * unreachable, so the overview was the only thing that responded. The entry
 * point is `toggle()` below, called from `shell.qml`'s handler, which keeps one
 * owner of the `ukishima` target.
 *
 * The overview stays out of `toggleSurface()` for a separate reason: that helper
 * is name-driven over the *pill's* surfaces, and this is a window in its own
 * right, not a pill surface.
 */
Scope {
    id: root

    /** Which monitor's grid is up. Empty means closed. */
    property string openMon: ""

    readonly property bool isOpen: openMon.length > 0

    /** Last monitor Hyprland reported focused; see `toggle`. */
    property string lastFocusedMon: ""

    /**
     * Show the grid on a monitor, or hide it if it is already up there. An empty
     * `mon` means the focused monitor, matching every other surface bind.
     *
     * `Hyprland.focusedMonitor` is null on a fresh launch, so this falls back to
     * the last known focused monitor and then to the first screen — otherwise
     * the bind would silently do nothing until something else had populated the
     * Hyprland models. The pill's `toggleSurface` has the same fallback.
     */
    function toggle(mon) {
        let m = mon;
        if (!m || m.length === 0) {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
                m = Hyprland.focusedMonitor.name;
            else if (root.lastFocusedMon.length > 0)
                m = root.lastFocusedMon;
            else if (Quickshell.screens.length > 0)
                m = Quickshell.screens[0].name;
        }
        root.openMon = (root.openMon === m) ? "" : m;
    }

    function close() {
        root.openMon = "";
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== root.lastFocusedMon)
                root.lastFocusedMon = Hyprland.focusedMonitor.name;
        }
    }

    Variants {
        model: Quickshell.screens

        OverviewWindow {
            open: root.openMon === modelData.name
            onRequestClose: root.close()
        }
    }
}
