pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 常 Dock pins: the ordered list of desktop-entry ids pinned to the bottom
 * dock, shared by every monitor's DockBar and by the launcher's right-click
 * pin action. Persisted as a plain JSON array in the state dir
 * (ukishima/dock-pins.json) through a FileView, so pinning survives restarts
 * and is safe to touch from any surface.
 */
Singleton {
    id: root

    readonly property string pinsFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/dock-pins.json"

    property var pins: []

    FileView {
        id: store
        path: root.pinsFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: root.load()

    function load() {
        var raw = store.text();
        try {
            var v = raw && raw.length > 0 ? JSON.parse(raw) : [];
            root.pins = Array.isArray(v) ? v : [];
        } catch (e) {
            root.pins = [];
        }
    }

    function save() {
        store.setText(JSON.stringify(root.pins));
    }

    function has(id) {
        return root.pins.indexOf(id) >= 0;
    }

    function toggle(id) {
        if (!id) return;
        var next = root.pins.slice();
        var i = next.indexOf(id);
        if (i >= 0) next.splice(i, 1); else next.push(id);
        root.pins = next;
        root.save();
    }
}