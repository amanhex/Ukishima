pragma Singleton
import QtQuick
import Quickshell

/**
 * Surface-lifecycle registry. Every pill instance registers itself here so the
 * shell can command all pills at once (the unloadAll IPC) without threading
 * pointers through the per-monitor screen Variants. Pills live for the whole
 * daemon lifetime, so the list is append-only and bounded by the monitor
 * count; de-registration is unnecessary.
 */
Singleton {
    id: root

    property var pills: []

    function register(p) {
        if (root.pills.indexOf(p) >= 0)
            return;
        root.pills = root.pills.concat([p]);
    }

    /**
     * Drop every closed surface on every pill immediately, leaving each open
     * surface (never in a pill's closedAt set) untouched. Callers expecting a
     * result get nothing back; the unloads happen synchronously.
     */
    function unloadClosed() {
        var list = root.pills;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].unloadClosedSurfaces)
                list[i].unloadClosedSurfaces();
    }
}