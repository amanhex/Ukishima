pragma Singleton

import QtQuick
import Quickshell

/**
 * The one compositor seam. Everything outside the providers talks to this
 * object; nothing else asks which window manager is running.
 *
 * `UKISHIMA_WM=hypr|hyprland|niri|generic` forces a provider. Left unset, Hyprland is chosen when its
 * instance signature is in the environment, generic otherwise. Adding another
 * compositor means one provider file and one branch here — no edits in the
 * pill, dock or workspaces strip.
 */
Singleton {
    id: root

    readonly property string requested: {
        const v = Quickshell.env("UKISHIMA_WM");
        return v && v.length > 0 ? v : "auto";
    }

    readonly property string provider: {
        if (requested === "hypr" || requested === "hyprland")
            return "hypr";
        if (requested === "generic" || requested === "niri")
            return "generic";
        const niri = Quickshell.env("NIRI_SOCKET");
        if (niri && niri.length > 0)
            return "generic";
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return sig && sig.length > 0 ? "hypr" : "generic";
    }

    // A ternary, not a provider map: an object literal evaluates both values,
    // which instantiates WmHyprland on niri and makes Quickshell.Hyprland log
    // "HYPRLAND_INSTANCE_SIGNATURE is unset" before the shell even asks for it.
    readonly property var impl: provider === "hypr" ? WmHyprland : WmGeneric

    /** Human name for messages: hyprland, niri, generic. Not used to branch. */
    readonly property string compositor: impl.compositor
    readonly property string keyboardLayoutName: impl.keyboardLayoutName || ""
    /** Feature gates for the few things one compositor cannot do. */
    readonly property var caps: impl.caps

    readonly property var windows: impl.windows
    function focusedScreenName() {
        return impl.focusedScreen() || "";
    }

    function screenFocused(name) {
        const focused = focusedScreenName();
        return focused.length === 0 || focused === name;
    }

    function workspacesFor(output) {
        return impl.workspacesFor(output);
    }

    function activateWorkspace(ws) {
        impl.activateWorkspace(ws);
    }

    function activeWorkspaceName(output) {
        return impl.activeWorkspaceName(output);
    }

    function specialWorkspaceName(output) {
        return impl.specialWorkspaceName(output);
    }

    function fullscreenOn(output) {
        return impl.fullscreenOn(output);
    }

    function focusWindow(win) {
        impl.focusWindow(win);
    }

    function minimizeWindow(addr) {
        impl.minimizeWindow(addr);
    }

    function restoreWindow(arg) {
        impl.restoreWindow(arg);
    }

    function logout() {
        impl.logout();
    }

    function refresh() {
        impl.refresh();
    }
}
