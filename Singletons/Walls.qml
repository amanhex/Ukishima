pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper bridge: keeps a warm in-memory snapshot of the wallpaper folder so
 * the wallpaper strip opens instantly without shelling out on demand. A
 * refresh first runs the thumbnail script (generating missing 512px previews
 * and pruning ones whose source is gone), then re-lists the directory
 * newest-first and finally re-reads the state file wallpaper.sh maintains, so
 * `current` always names the wallpaper on screen. Thumbnails land before the
 * list so strip delegates never bind to a not-yet-existing file; a refresh
 * arriving while the pipeline runs sets `pending` and replays once the state
 * lands. Applying routes through wallpaper.sh so the picker shares the exact
 * transition, palette and state path with the random keybind.
 *
 * The folder resolves through one chain, first hit wins: an explicit
 * `wallpaperDir` in flags.json, then the dir wallpaper.sh resolved and wrote
 * to the ukishima-wallpaper-dir state file on its last run, then
 * ~/Pictures/Wallpapers for a first boot before wallpaper.sh init has run.
 *
 * The pipeline never runs on its own: it is triggered only by the wallpaper
 * strip's refresh button or an explicit folder change, never when the strip
 * opens, so thumbnails are generated strictly on demand.
 *
 * Thumbs live in per-folder subdirectories of the ukishima-wp-thumbs cache, each
 * keyed by the md5 of its wallpaper folder's path. Files sharing a basename
 * across folders therefore never clobber each other, and switching folders
 * can't surface a stale thumb from the previous one; each folder's cache is
 * pruned and regenerated independently.
 *
 * Entries are plain objects: { path, name, mtime, thumb } where path is the
 * absolute source file, mtime its modification time in epoch seconds and
 * thumb the absolute path of the cached preview png.
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property string current: ""
    property bool pending: false

    /**
     * True while a refresh pipeline is in flight (thumbs → listing → state).
     * The wallpaper strip's refresh control spins while it is set, then snaps
     * back once the state read lands and `refreshDone` fires.
     */
    property bool refreshing: false

    /**
     * Fired once a full refresh pipeline has landed: thumbnails regenerated and
     * pruned, the listing re-read and `current` re-read from the state file.
     * Subscribers (the wallpaper strip) use it to re-centre on the wallpaper on
     * screen, which may have changed while they were closed.
     */
    signal refreshDone()

    property string resolvedDir: ""
    readonly property string wpDir: Flags.wallpaperDir.length > 0 ? Flags.wallpaperDir
        : (resolvedDir.length > 0 ? resolvedDir : Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima-wp-thumbs/"
    readonly property string thumbScript: Config.hyprPath("scripts", "wallpaper-thumbs.sh")
    readonly property string setScript: Config.hyprPath("scripts", "wallpaper.sh")
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima-wallpaper"
    readonly property string dirStateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima-wallpaper-dir"

    FileView {
        id: dirFile
        path: root.dirStateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.resolvedDir = dirFile.text().trim()
        onFileChanged: reload()
        onLoadFailed: root.resolvedDir = ""
    }

    function refresh() {
        if (resolveProc.running || thumbProc.running || listProc.running || stateProc.running) {
            pending = true;
            return;
        }
        refreshing = true;
        /**
         * Re-resolve the folder first when autodetect is in play: it only runs
         * inside wallpaper.sh, so a shell restart used to leave the strip on
         * the stale state file. An explicit folder skips that hop entirely and
         * swaps straight away.
         */
        if (Flags.wallpaperDir.length > 0) {
            thumbProc.running = true;
            return;
        }
        resolveProc.command = ["bash", root.setScript, "resolve"];
        resolveProc.running = true;
    }

    Process {
        id: resolveProc
        onExited: thumbProc.running = true
    }

    /**
     * wallpaper.sh blocks through the whole transition (awww wave, matugen,
     * reload), easily 1-2s; a pick landing in that window used to be silently
     * swallowed. Now the newest request is queued and replayed once the
     * running transition exits, so rapid iteration converges on the last pick.
     */
    property string queuedApply: ""
    property string queuedOutput: ""

    function apply(path, output) {
        var out = output === undefined ? "" : output;
        if (applyProc.running) {
            queuedApply = path;
            queuedOutput = out;
            return;
        }
        applyProc.command = out.length > 0
            ? ["bash", root.setScript, "set", path, out]
            : ["bash", root.setScript, "set", path];
        applyProc.running = true;
    }

    function trash(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].path !== path)
                kept.push(entries[i]);
        entries = kept;
    }

    Process {
        id: trashProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c",
            "key=$(printf %s \"$1\" | md5sum | cut -d' ' -f1); "
            + "find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) -printf '%T@\\t%p\\n' | sort -rn "
            + "| awk -F'\\t' -v c=\"$2$key\" '{ n = split($2, p, \"/\"); printf \"%s\\t%s\\t%s\\n\", $1, $2, c \"/\" p[n] \".png\" }'",
            "_", root.wpDir, root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var t1 = lines[i].indexOf("\t");
                    if (t1 < 1)
                        continue;
                    var t2 = lines[i].indexOf("\t", t1 + 1);
                    if (t2 < 0)
                        continue;
                    var path = lines[i].substring(t1 + 1, t2);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    out.push({
                        path: path,
                        name: name,
                        mtime: parseFloat(lines[i].substring(0, t1)),
                        thumb: lines[i].substring(t2 + 1)
                    });
                }
                root.entries = out;
                stateProc.running = true;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                if (root.pending) {
                    root.pending = false;
                    Qt.callLater(root.refresh);
                } else {
                    root.refreshing = false;
                    root.refreshDone();
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                var nextOut = root.queuedOutput;
                root.queuedApply = "";
                root.queuedOutput = "";
                applyProc.command = nextOut.length > 0
                    ? ["bash", root.setScript, "set", next, nextOut]
                    : ["bash", root.setScript, "set", next];
                applyProc.running = true;
                return;
            }
            stateProc.running = true;
        }
    }

    /**
     * Fit-mode change: wallpaper.sh "fit <mode>" (no transition, no palette
     * run) re-images the current stills through aww with the new --resize and
     * respawns videos with matching mpv scaling. Fast enough that rapid clicks
     * are rare, but the same one-slot latch as apply() keeps the last pick from
     * being dropped while an earlier one still runs.
     */
    property string queuedFit: ""

    function applyFit(mode) {
        if (fitProc.running) {
            queuedFit = mode;
            return;
        }
        fitProc.command = ["bash", root.setScript, "fit", mode];
        fitProc.running = true;
    }

    Process {
        id: fitProc
        onExited: {
            if (root.queuedFit.length) {
                var next = root.queuedFit;
                root.queuedFit = "";
                fitProc.command = ["bash", root.setScript, "fit", next];
                fitProc.running = true;
            }
        }
    }
}
