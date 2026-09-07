pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * cliphist bridge: keeps a warm in-memory snapshot of the clipboard history so
 * the clipboard surface opens instantly without shelling out on demand. A
 * wl-paste watcher fires on every clipboard change. While the clipboard surface
 * is open, after a short debounce the thumbnail script regenerates missing
 * image previews (and prunes stale ones), then `cliphist list` is re-read into
 * `entries` — live streaming while the user is looking at the list. While the
 * surface is closed the change only marks the snapshot `dirty` and nothing is
 * spawned; the next open re-pulls through refresh(). Thumbnails are written
 * before the list lands so image delegates never bind to a not-yet-existing
 * file. A change arriving while the pipeline runs sets `pending` (or `dirty`
 * when closed) and replays once the list lands, so no clipboard event is ever
 * silently dropped; the watcher respawns through a cooldown timer if wl-paste
 * dies.
 *
 * Entries are plain objects: { id, preview, isImage, meta, label, sizeLabel,
 * thumb } where meta is cliphist's raw binary descriptor ("245 KiB png
 * 1920x1080"), label/sizeLabel its display split ("png 1920×1080" / "245 KiB")
 * and thumb the absolute path of the cached preview png (empty for text).
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property bool pending: false

    /**
     * The clipboard surface passes this to its `active` state so a change
     * landing while the surface is closed is deferred instead of spawning the
     * thumbnail script + cliphist list in the background all day.
     */
    property bool surfaceOpen: false

    /**
     * A clipboard change arrived while the surface was closed. refresh()
     * clears it, so the snapshot is authoritative again once it finishes a
     * pull (whether from a live change or from opening the surface).
     */
    property bool dirty: true

    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima/cliphist-thumbs/"
    readonly property string thumbScript: Config.hyprPath("scripts", "cliphist-thumbs.sh")

    function refresh() {
        dirty = false;
        if (thumbProc.running || listProc.running || delProc.running || delQueue.length) {
            pending = true;
            return;
        }
        thumbProc.running = true;
    }

    function copy(entry) {
        if (!/^\d+$/.test(String(entry.id)))
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)]);
    }

    function wipe() {
        entries = [];
        wipeProc.running = true;
    }

    /**
     * Deletes are queued through a tracked process and any refresh is held
     * until the queue drains: a fire-and-forget delete racing an in-flight
     * `cliphist list` used to resurrect the removed entry from the stale
     * snapshot. The local prune stays optimistic so the row vanishes
     * immediately.
     */
    property var delQueue: []

    function remove(entry) {
        var id = String(entry.id);
        if (!/^\d+$/.test(id))
            return;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].id !== id)
                kept.push(entries[i]);
        entries = kept;
        delQueue.push(id);
        pumpDeletes();
    }

    function pumpDeletes() {
        if (delProc.running || !delQueue.length)
            return;
        var id = delQueue.shift();
        delProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", id];
        delProc.running = true;
    }

    Process {
        id: delProc
        onExited: {
            if (root.delQueue.length)
                root.pumpDeletes();
            else if (root.surfaceOpen)
                root.refresh();
            else
                root.dirty = true;
        }
    }

    Process {
        id: watchProc
        command: ["wl-paste", "--watch", "echo", "x"]
        running: true
        stdout: SplitParser {
            onRead: {
                if (root.surfaceOpen)
                    debounce.restart();
                else
                    root.dirty = true;
            }
        }
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 2000
        onTriggered: watchProc.running = true
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: if (root.surfaceOpen) root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: {
            if (root.surfaceOpen)
                root.refresh();
            else
                root.dirty = true;
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                var metaRe = /^\[\[ binary data (.*) \]\]$/;
                var imgRe = /\b(png|jpg|jpeg|gif|bmp|webp)\b/;
                var splitRe = /^(\S+ \S+) (\w+) (\d+)x(\d+)$/;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    var tab = line.indexOf("\t");
                    if (tab < 1)
                        continue;
                    var id = line.substring(0, tab);
                    if (!/^\d+$/.test(id))
                        continue;
                    var preview = line.substring(tab + 1);
                    var m = metaRe.exec(preview);
                    var isImage = m !== null && imgRe.test(m[1]);
                    var label = "";
                    var sizeLabel = "";
                    if (isImage) {
                        var p = splitRe.exec(m[1]);
                        label = p ? p[2] + " " + p[3] + "×" + p[4] : m[1];
                        sizeLabel = p ? p[1] : "";
                    }
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: isImage,
                        label: label,
                        sizeLabel: sizeLabel,
                        thumb: isImage ? root.thumbDir + id + ".png" : ""
                    });
                }
                root.entries = out;
                if (root.pending) {
                    root.pending = false;
                    if (root.surfaceOpen)
                        Qt.callLater(root.refresh);
                    else
                        root.dirty = true;
                }
            }
        }
    }

    Component.onCompleted: refresh()
}
