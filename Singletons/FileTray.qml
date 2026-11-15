pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * File tray: an ordered list of references — absolute file paths and http(s)
 * URLs — persisted as a plain JSON array in the state dir. Local files are
 * referenced in place, never copied, so the tray costs no disk and a file that
 * moves simply stops resolving. Adding is one write path (`add`): drops, the
 * browse picker and external callers all funnel through it, so dedupe and save
 * can never be skipped.
 *
 * Drag-out is done by the surface with Qt Quick's `Drag` attached type, which
 * starts a real Wayland drag whose payload is a text/uri-list — the type file
 * managers and apps accept as files.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (root.home + "/.local/state")) + "/ukishima"
    readonly property string storeFile: root.stateDir + "/file-tray.json"
    /** Fetched copies of remote images; see `addDropped`. */
    readonly property string fetchDir: (Quickshell.env("XDG_CACHE_HOME") || (root.home + "/.cache")) + "/ukishima/tray"

    property var files: []
    readonly property int count: files.length
    readonly property bool empty: files.length === 0

    /**
     * True while a tile is being dragged out. The pill overlay is modal while a
     * surface is open (full-screen input region), and a compositor targets a
     * Wayland drag at the surface under the pointer — so the overlay would take
     * its own drag and no app would ever see a drop. The shell drops back to the
     * pill-sized region for the duration (see `mask` in shell.qml).
     */
    property bool dragging: false

    /**
     * What the tray surface shows, and in which order: the chip filter ("" for
     * everything, "files", "links"), the search field's text, and the sort key
     * (`name`, `recent`, `type`). Kept here rather than in the surface so the
     * filter survives the surface being rebuilt, and because only the singleton
     * knows how to tell a file from a link.
     *
     * `view` is what the strip draws: the same paths filtered and
     * sorted, as a plain array so the delegates keep taking `modelData`.
     */
    property string filter: ""
    property string query: ""
    property string sort: "recent"

    readonly property int fileCount: root.countKind(false)
    readonly property int linkCount: root.countKind(true)

    function countKind(remote) {
        var n = 0;
        for (var i = 0; i < root.files.length; i++) {
            if (root.isRemote(root.files[i]) === remote)
                n++;
        }
        return n;
    }

    readonly property var view: {
        var q = root.query.toLowerCase();
        var out = [];
        for (var i = 0; i < root.files.length; i++) {
            var p = root.files[i];
            var remote = root.isRemote(p);
            if (root.filter === "files" && remote)
                continue;
            if (root.filter === "links" && !remote)
                continue;
            if (q.length > 0 && root.nameOf(p).toLowerCase().indexOf(q) < 0)
                continue;
            out.push(p);
        }
        /* `files[]` is in the order entries were added, so newest first is just
         * the reverse — no stat needed for the sort the tray actually wants. */
        if (root.sort === "recent")
            out.reverse();
        else if (root.sort === "type")
            out.sort((a, b) => root.extOf(a).localeCompare(root.extOf(b))
                || root.nameOf(a).localeCompare(root.nameOf(b)));
        else
            out.sort((a, b) => root.nameOf(a).localeCompare(root.nameOf(b)));
        return out;
    }

    /** `ok` is false when wl-copy could not take the selection. */
    signal copied(bool ok)

    FileView {
        id: store
        path: root.storeFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    Component.onCompleted: root.load()

    function load() {
        var out = [];
        var changed = false;
        try {
            var v = store.text();
            var parsed = v && v.length > 0 ? JSON.parse(v) : [];
            if (Array.isArray(parsed)) {
                for (var i = 0; i < parsed.length; i++) {
                    var p = typeof parsed[i] === "string" ? parsed[i]
                        : (parsed[i] && parsed[i].path ? parsed[i].path : "");
                    /* Only absolute files and http(s) references survive; a
                     * bare name from an old browser drag must not. Dedupe at
                     * the same time, and self-heal the store when dropping. */
                    if ((p.charAt(0) === "/" || root.isRemote(p)) && out.indexOf(p) < 0)
                        out.push(p);
                    else
                        changed = true;
                }
            }
        } catch (e) {
            out = [];
        }
        root.files = out;
        if (changed)
            root.save();
    }

    function save() {
        store.setText(JSON.stringify(root.files));
    }

    /** Normalise a drop URL or plain path: local paths lose `file://`, remote URLs stay intact. */
    function pathOf(value) {
        if (value === undefined || value === null)
            return "";
        var s = String(value);
        if (s.indexOf("file://") === 0) {
            s = s.substring(7);
            try { s = decodeURIComponent(s); } catch (e) {}
        }
        return s;
    }

    /**
     * A browser drag carries `https://…`, not a local file. Keeping the URL is
     * the only reference there is (no path to stat), and it is what another app
     * can receive back later — as a link or as an image source.
     */
    function isRemote(value) {
        return /^https?:\/\//i.test(String(value || ""));
    }

    /** Add paths/URLs; returns how many were new. Dedupes and saves once. */
    function add(paths) {
        if (!paths)
            return 0;
        var arr = Array.isArray(paths) ? paths : [paths];
        var next = root.files.slice();
        var added = 0;
        for (var i = 0; i < arr.length; i++) {
            var p = root.pathOf(arr[i]);
            /* Absolute files and http(s) references only: a bare name or a
             * javascript:/data: payload from a drag must not become an entry. */
            if (!p || (!root.isRemote(p) && p.charAt(0) !== "/") || next.indexOf(p) >= 0)
                continue;
            next.push(p);
            added++;
        }
        if (added > 0) {
            root.files = next;
            root.save();
        }
        return added;
    }

    /** Notifies the open tray how many files a drop actually landed. */
    signal added(int count)

    /**
     * Drop gateway. Directories are rejected here rather than in `add`: a
     * folder reference cannot be dragged out as a file and has no preview, so
     * it would only be a dead tile. QML has no stat, so one shell pass filters
     * the batch (`-f` follows symlinks, rejects dirs, sockets and fifos), then
     * `add` commits what remains.
     *
     * A browser drop is not a file: it carries a CDN URL, which is signed and
     * expires, and no app accepts an http URL as a picture. Remote images are
     * therefore fetched once into the cache and kept as the downloaded file;
     * if the fetch fails the link is kept instead. Other remote URLs stay
     * links — there is nothing to materialise.
     */
    function addDropped(paths) {
        if (!paths || paths.length === 0)
            return;
        var links = [];
        var images = [];
        var local = [];
        for (var i = 0; i < paths.length; i++) {
            var s = String(paths[i]);
            if (root.isRemote(s)) {
                if (root.isImage(s))
                    images.push(s);
                else
                    links.push(s);
                continue;
            }
            var p = root.pathOf(s);
            if (p && p.charAt(0) === "/")
                local.push(p);
        }
        if (links.length > 0)
            root.added(root.add(links));
        if (images.length > 0) {
            root.fetchQueue = root.fetchQueue.concat(images);
            root.pumpFetch();
        }
        if (local.length > 0)
            root.verifyLocals(local);
    }

    property var fetchQueue: []

    function pumpFetch() {
        if (fetchProc.running || root.fetchQueue.length === 0)
            return;
        var u = root.fetchQueue.shift();
        fetchProc.source = u;
        fetchProc.command = ["sh", "-c",
            "d=\"$1\"; u=\"$2\"; e=\"$3\"; " +
            "id=$(printf %s \"$u\" | sha1sum | cut -c1-8); " +
            "base=$(printf %s \"$u\" | sed 's/[?#].*$//' | sed 's|.*/||' | sed 's/[^A-Za-z0-9._-]/_/g' | cut -c1-40); " +
            "[ -n \"$base\" ] || base=image; " +
            "case \"$base\" in *.*) ;; *) base=\"$base.$e\" ;; esac; " +
            "mkdir -p \"$d\"; f=\"$d/$id-$base\"; " +
            "if [ ! -s \"$f\" ]; then " +
            "  curl -fsSL --max-time 20 -A \"Mozilla/5.0\" -o \"$f.part\" \"$u\" || { rm -f \"$f.part\"; exit 1; }; " +
            "  case \"$(file -b --mime-type \"$f.part\")\" in image/*) mv -f \"$f.part\" \"$f\" ;; *) rm -f \"$f.part\"; exit 1 ;; esac; " +
            "fi; printf %s \"$f\"", "_", root.fetchDir, u, root.extOf(u) || "jpg"];
        fetchProc.running = true;
    }

    /* ponytail: the cache is never pruned; a signed CDN link is dead within
     * hours, so keep the bytes. Add a size cap when the folder gets big. */
    Process {
        id: fetchProc
        property string source: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var f = this.text.trim();
                /* A failed fetch falls back to the link, so the drop is never
                 * silently lost just because the CDN refused it. */
                root.added(root.add([f.length > 0 ? f : fetchProc.source]));
                fetchProc.source = "";
                root.pumpFetch();
            }
        }
    }

    /** One `[ -f ]` pass per local batch, queued so a drop during a check is kept. */
    property var verifyQueue: []

    function verifyLocals(local) {
        if (verifyProc.running) {
            root.verifyQueue.push(local);
            return;
        }
        verifyProc.command = ["sh", "-c",
            "for p in \"$@\"; do [ -f \"$p\" ] && printf '%s\\n' \"$p\"; done", "_"].concat(local);
        verifyProc.running = true;
    }

    Process {
        id: verifyProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.added(root.add(this.text.split("\n")));
                if (root.verifyQueue.length > 0)
                    root.verifyLocals(root.verifyQueue.shift());
            }
        }
    }

    function remove(path) {
        var i = root.files.indexOf(path);
        if (i < 0)
            return;
        var next = root.files.slice();
        next.splice(i, 1);
        root.files = next;
        root.save();
    }

    function clear() {
        if (root.files.length === 0)
            return;
        root.files = [];
        root.save();
    }

    function has(path) {
        return root.files.indexOf(path) >= 0;
    }

    function nameOf(path) {
        var s = String(path || "");
        if (root.isRemote(s)) {
            var noQuery = s.replace(/[?#].*$/, "").replace(/\/+$/, "");
            var seg = noQuery.substring(noQuery.lastIndexOf("/") + 1);
            /* A direct file name tells you more than a host; a bare page id
             * (instagram.com/p/AbC123) does not, so fall back to the host. */
            if (seg && seg.indexOf(".") > 0)
                return seg;
            return noQuery.replace(/^https?:\/\//i, "").split("/")[0];
        }
        return s.substring(s.lastIndexOf("/") + 1);
    }

    function extOf(path) {
        var s = String(path || "");
        if (root.isRemote(s)) {
            var noQuery = s.replace(/[?#].*$/, "");
            var seg = noQuery.substring(noQuery.lastIndexOf("/") + 1);
            var dot = seg.lastIndexOf(".");
            if (dot >= 0)
                return seg.substring(dot + 1).toLowerCase();
            /* Some CDNs put the type in the query: …/media/ABC?format=jpg */
            var m = /[?&](?:format|fm)=([a-z0-9]+)/i.exec(s);
            return m ? m[1].toLowerCase() : "";
        }
        var name = root.nameOf(s);
        var dot = name.lastIndexOf(".");
        return dot >= 0 ? name.substring(dot + 1).toLowerCase() : "";
    }

    function isImage(path) {
        return /^(png|jpe?g|gif|webp|avif|bmp|svg|heic|heif|tiff?)$/.test(root.extOf(path));
    }

    function isVideo(path) {
        return /^(mp4|mkv|mov|webm|avi|m4v)$/.test(root.extOf(path));
    }

    function isAudio(path) {
        return /^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(root.extOf(path));
    }

    /** Plain-text-ish types that can show a live excerpt instead of a bitmap. */
    function isText(path) {
        return /^(txt|md|markdown|rst|log|conf|cfg|ini|toml|yaml|yml|json|csv|tsv|sh|bash|zsh|py|js|ts|jsx|tsx|css|html|xml|qml|rs|c|h|cpp|hpp|go|java|lua|nix)$/.test(root.extOf(path));
    }

    function glyphFor(path) {
        if (root.isImage(path)) return "wallpaper";
        if (root.isVideo(path)) return "video";
        if (root.isAudio(path)) return "music";
        if (root.isRemote(path)) return "link";
        if (/^(pdf|docx?|odt|txt|md|rtf|epub)$/.test(root.extOf(path))) return "type";
        return "folder";
    }

    function uriFor(path) {
        var s = String(path || "");
        if (root.isRemote(s))
            return s; // already a URI; never re-encode it
        var parts = s.split("/");
        for (var i = 0; i < parts.length; i++)
            parts[i] = encodeURIComponent(parts[i]);
        return "file://" + parts.join("/");
    }

    /** RFC 2483 payload: one URI per line, CRLF-terminated like both reference shells. */
    function uriList(paths) {
        var out = "";
        for (var i = 0; i < paths.length; i++)
            out += root.uriFor(paths[i]) + "\r\n";
        return out;
    }

    /** What a text target (editor, chat box) should receive for the same entry. */
    function plainFor(path) {
        var s = String(path || "");
        return root.isRemote(s) ? s : root.pathOf(s);
    }

    /**
     * Click fallback: put the entry on the clipboard so it can be pasted.
     * `wl-copy` offers plain-text aliases alongside text/uri-list, so the same
     * entry pastes as a file in a file manager and as a URL/path in a text
     * field. It forks to hold the selection, so its exit only reports that the
     * handoff worked; the surface notifies from that instead of guessing.
     */
    Process {
        id: copyProc
        property string pendingPath: ""
        command: ["sh", "-c",
            "printf '%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "_", ""]
        onExited: (code) => {
            root.copied(code === 0);
            if (copyProc.pendingPath.length > 0) {
                var next = copyProc.pendingPath;
                copyProc.pendingPath = "";
                Qt.callLater(() => root.copy(next));
            }
        }
    }

    function copy(path) {
        if (!path)
            return;
        /* A double-click fires a click first; keep the newest request instead
         * of losing it to the copy already holding the selection. */
        if (copyProc.running) {
            copyProc.pendingPath = path;
            return;
        }
        copyProc.command = ["sh", "-c",
            "printf '%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "_", root.uriFor(path)];
        copyProc.running = true;
    }

    function open(path) {
        if (path)
            Quickshell.execDetached(["xdg-open", path]);
    }

    /**
     * Tile previews. Images — local files or http(s) URLs — draw straight from
     * the source, since Quickshell's Image handles both. Videos get a cached
     * still from scripts/tray-thumbs.sh (ffmpeg, already a wallpaper/recording
     * dependency) and text files get a live excerpt. Everything else keeps its
     * type glyph, so nothing here needs a new package.
     *
     * `previews[path]` holds either { image: "file://..." } or { text: "..." };
     * a null entry is a definitive "no preview" so a dead file is not retried
     * every time a tile renders. Generation is serialised through one Process
     * so a whole folder dropped at once cannot spawn a decoder per tile.
     */
    property var previews: ({})
    property var previewQueue: []

    function ensurePreview(path) {
        if (!path || root.isImage(path) || root.isRemote(path)
            || !(root.isVideo(path) || root.isText(path)) || root.previews[path] !== undefined)
            return;
        var next = {};
        for (var k in root.previews)
            next[k] = root.previews[k];
        next[path] = null; // pending
        root.previews = next;
        root.previewQueue = root.previewQueue.concat([path]);
        root.pumpPreview();
    }

    function pumpPreview() {
        if (previewProc.running || root.previewQueue.length === 0)
            return;
        var p = root.previewQueue[0];
        previewProc.target = p;
        previewProc.command = root.isText(p)
            ? ["head", "-c", "500", "--", p]
            : ["bash", Config.hyprPath("scripts", "tray-thumbs.sh"), p];
        previewProc.running = true;
    }

    Process {
        id: previewProc
        property string target: ""
        stdout: StdioCollector {
            id: previewOut
            property string collected: ""
            onStreamFinished: collected = text
        }
        onExited: {
            var p = previewProc.target;
            var out = previewOut.collected.trim();
            var next = {};
            for (var k in root.previews)
                next[k] = root.previews[k];
            next[p] = out.length === 0 ? null
                : (root.isText(p) ? { text: out } : { image: "file://" + out });
            root.previews = next;
            root.previewQueue = root.previewQueue.slice(1);
            previewProc.target = "";
            root.pumpPreview();
        }
    }

    /** Native multi-file picker. Drag-in still works when neither tool exists. */
    Process {
        id: browseProc
        command: ["sh", "-c",
            "command -v zenity >/dev/null 2>&1 && zenity --file-selection --multiple --separator=$'\\n' 2>/dev/null || kdialog --getopenfilename \"$HOME\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.add(this.text.split("\n"))
        }
    }

    function browse() {
        browseProc.running = true;
    }
}
