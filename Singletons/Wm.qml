pragma Singleton

import QtQuick
import Quickshell

/**
 * The one compositor seam. Everything outside the providers talks to this
 * object; nothing else asks which window manager is running.
 *
 * `UKISHIMA_WM=hypr|generic` forces a provider (useful to test the generic
 * path while still inside Hyprland). Left unset, Hyprland is chosen when its
 * instance signature is in the environment, generic otherwise. Adding another
 * compositor means one entry in `providers` and one provider file — no edits
 * in the pill, dock or workspaces strip.
 */
Singleton {
    id: root

    readonly property string requested: {
        const v = Quickshell.env("UKISHIMA_WM");
        return v && v.length > 0 ? v : "auto";
    }

    readonly property string provider: {
        if (requested === "hypr" || requested === "generic")
            return requested;
        const sig = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        return sig && sig.length > 0 ? "hypr" : "generic";
    }

    readonly property var providers: ({
        hypr: WmHyprland,
        generic: WmGeneric
    })

    readonly property var impl: providers[provider] || WmGeneric

    /** Human name for messages: hyprland, niri, generic. Not used to branch. */
    readonly property string compositor: impl.compositor
    /** Feature gates for the few things one compositor cannot do. */
    readonly property var caps: impl.caps

    readonly property var windows: impl.windows
    readonly property string focusedScreenName: impl.focusedScreenName

    function screenFocused(name) {
        return focusedScreenName.length === 0 || focusedScreenName === name;
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

    function refresh() {
        impl.refresh();
    }
}
