pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 場 SPACES store: the reader of the Hyprland spaces config, the user-defined
 * special workspaces. Each entry is { id, name }: id is the special-workspace
 * name, name its display name.
 *
 * This is a READER now, and deliberately a small one. It used to be the single
 * read/writer: it regenerated the whole lua file through an atomic writer, fired
 * a debounced `hyprctl reload` after every change, and exposed add/remove/rename,
 * rebind, app-routing and key-clash-check for a Workspaces settings page and a
 * SpaceApps surface to drive. Neither surface exists, so none of that had a
 * caller — roughly 150 lines reachable only from a UI that was never built, and
 * an atomic writer plus a `hyprctl reload` on a path nothing could reach.
 *
 * What is left is what the pill actually uses: `list`, so a special workspace's
 * id can be shown by its display name instead of its slug. The file is watched, so
 * a hand-edited spaces.lua is picked up without a restart.
 *
 * The write path is worth restoring the moment a page needs it, and this is the
 * shape it had: the whole file is regenerated from `list`, the write goes through
 * an atomic FileView, and `onSaved` fires a debounced reload so Hyprland re-reads
 * it. Key clashes were checked against both `list` and binds.lua; the parser for
 * that lua used to live in `lib/binds.js`, and it went with the Keybinds surface
 * it belonged to, so a restored writer needs its own clash check or none.
 * What was removed is the mechanism, not the design.
 */
Singleton {
    id: root

    readonly property string path: Config.hyprPath("modules", "spaces.lua")

    property var list: []

    /** Pull the fields the pill reads out of one `{ ... }` entry block. Null without an id. */
    function parseEntry(block) {
        var id = root.field(block, "id");
        if (id.length === 0)
            return null;
        return {
            id: id,
            name: root.field(block, "name") || id
        };
    }

    function field(block, key) {
        var m = block.match(new RegExp("\\b" + key + "\\s*=\\s*\"([^\"]*)\""));
        return m ? m[1] : "";
    }

    /**
     * Walk the `return { ... }` table brace by brace, slicing every top-level
     * entry block (depth 2) and parsing it. The nested apps `{ ... }` sits at
     * depth 3 so it never opens a spurious entry.
     */
    function parse(text) {
        var ri = text.indexOf("return");
        var body = ri >= 0 ? text.slice(ri) : text;
        var ob = body.indexOf("{");
        if (ob < 0)
            return [];
        var out = [];
        var depth = 0;
        var start = -1;
        for (var i = ob; i < body.length; i++) {
            var c = body[i];
            if (c === "{") {
                depth++;
                if (depth === 2)
                    start = i;
            } else if (c === "}") {
                if (depth === 2 && start >= 0) {
                    var e = root.parseEntry(body.slice(start, i + 1));
                    if (e)
                        out.push(e);
                    start = -1;
                }
                depth--;
                if (depth === 0)
                    break;
            }
        }
        return out;
    }

    function refresh() {
        root.list = root.parse(spacesFile.text());
    }

    FileView {
        id: spacesFile
        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    Component.onCompleted: root.refresh()
}
