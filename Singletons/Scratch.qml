pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Scratchpad model: a shelf of plain-text notes, one file per note, so the
 * pill's scratchpad and any editor see the same bytes. Notes live in
 * `ukishima/notes` under the state dir and the title IS the filename — renaming
 * a note is an `mv`, and a note with no extension surprise stays openable with
 * `cat`. Bodies are read on selection and written back through a debounced
 * autosave, so nothing is ever held only in QML memory.
 *
 * Pinned notes sort above the rest and carry their flag in a sidecar JSON
 * (scratch-pins.json) rather than in the body, which keeps the files themselves
 * portable — a note dropped in by hand arrives unpinned with no metadata to
 * strip. `scan()` is the single source of the list: `find` reports name, mtime
 * and size in one pass, pins are merged in, and the result is sorted pinned
 * first then newest, so the surface never has to re-sort.
 *
 * Writing goes through `printf > tmp && mv` rather than a FileView: the save
 * path changes with every selection, and re-pointing a FileView races its own
 * pending load. A shell replace is atomic by rename and has no such window.
 * That caps a body at the argv limit (~2 MiB) — far past what a note needs, and
 * the same ceiling `setText` would have imposed anyway.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/ukishima"
    readonly property string notesDir: stateDir + "/notes"
    readonly property string pinsFile: stateDir + "/scratch-pins.json"

    /** Bodies are edited as raw text, not rendered — a markdown preview would need a parser. */
    readonly property string ext: ".md"

    /**
     * The scanner only matches `*.md`, so the atomic-write staging file is named
     * to stay outside that glob. If it ever matched, an interrupted save would
     * leave the temp file listed as a note.
     */
    readonly property string tmpName: ".ukisave"

    /**
     * Sorted, pinned-first. Entries are `{ slug, title, path, pinned, mtime,
     * sizeLabel, heading, preview }`; `slug` is the extensionless filename and
     * doubles as the identity used by the selection and the pin map. `heading`
     * is the note's own lead line when the body opens with one (a `#` mark or a
     * short line above a body); `preview` is everything after it.
     */
    property var notes: []
    readonly property bool any: notes.length > 0

    property string currentSlug: ""
    readonly property var current: {
        for (var i = 0; i < root.notes.length; i++)
            if (notes[i].slug === root.currentSlug)
                return notes[i];
        return null;
    }

    /** Editor buffer. Owned by the surface while it is open, flushed on autosave. */
    property string draft: ""
    property bool dirty: false

    /**
     * Bumped by every user keystroke. A body read only adopts its result if this
     * is unchanged since the read started, because a `cat` of a large note is
     * still in flight when the user starts typing and would otherwise land on top
     * of the newer text and silently discard it.
     */
    property int editEpoch: 0

    /**
     * The only write path into the buffer, so the epoch and the dirty flag cannot
     * be forgotten by a caller. Everything that marks a note edited goes through
     * here — a caller that assigns `draft` directly would save nothing.
     */
    function type(text: string) {
        root.draft = text;
        root.dirty = true;
        root.editEpoch++;
    }

    /**
     * The scratchpad surface's `active`, so a scan is not spawned on every
     * keystroke-triggered refresh while the pad is closed. Editing a note
     * outside the pill (in $EDITOR) is picked up on the next open.
     */
    property bool surfaceOpen: false

    property var pins: ({})

    /**
     * A body finished loading from disk. The surface pushes this into its editor
     * rather than binding `text` to `draft`: a binding would reassign `text` on
     * every autosave-triggered rescan and wipe the undo stack under the user.
     */
    signal bodyLoaded(string slug, string body)

    FileView {
        id: pinStore
        path: root.pinsFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        root.loadPins();
        root.scan();
    }

    /** Re-read the note list. One `find` pass; pinned-first then newest. */
    function scan() {
        scanProc.running = true;
    }

    Process {
        id: scanProc
        command: ["sh", "-c",
            //* One pass over the directory, and the only scan there is. Bodies are read
            //* here (flattened, truncated) so the deck can show a note's first lines as
            //* its card content — `find` alone only reports names and mtimes, which makes
            //* the deck a column of bare titles. Never touches the editor buffer: these
            //* are previews, not note bodies.
            //
            //* The first line is read apart from the rest so the deck can lift a note's
            //* heading from a `#`-opening. Filename LAST, and mtime/size before it, so
            //* a hand-dropped note whose name contains a tab can be rejoined from the
            //* tail rather than shifting every later field out from under its meaning.
            //* Titles typed in the pad are sanitized, so only a file arriving from
            //* outside can do this.
            "d=\"$1\"; [ -d \"$d\" ] || exit 0; for f in \"$d\"/*.md; do [ -f \"$f\" ] || continue; first=\"$(head -n 1 -- \"$f\" | tr '\\t\\r\\n' '   ')\"; rest=\"$(tail -n +2 -- \"$f\" | head -c 240 | tr '\\t\\r\\n' '   ')\"; printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$(stat -c %Y -- \"$f\")\" \"$(stat -c %s -- \"$f\")\" \"$first\" \"$rest\" \"${f##*/}\"; done",
            "_", root.notesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                var now = Date.now() / 1000;
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i])
                        continue;
                    var cols = lines[i].split("\t");
                    if (cols.length < 5)
                        continue;
                    var mtime = parseFloat(cols[0]);
                    var size = parseInt(cols[1]);
                    var first = root.squeeze(cols[2]);
                    var rest = root.squeeze(cols[3]);
                    var name = cols.slice(4).join("\t");
                    if (!name.endsWith(root.ext))
                        continue;
                    //* The scanner reports the filename with its extension; the slug is
                    //* the identity, the title and the pin key, so it drops back off.
                    var slug = name.substring(0, name.length - 3);
                    //* A file named exactly ".md" leaves an empty slug, which
                    //* collides with "nothing selected" and would draw a ghost
                    //* card. It is not a note; skip it.
                    if (!slug)
                        continue;
                    var age = Math.max(0, now - mtime);
                    var heading = root.headingOf(first, rest);
                    out.push({
                        slug: slug,
                        title: slug,
                        path: root.notesDir + "/" + name,
                        pinned: root.pins[slug] === true,
                        mtime: mtime,
                        heading: heading,
                        preview: heading ? rest : (first ? (rest ? first + " " + rest : first) : rest),
                        sizeLabel: size < 1024 ? size + " B" : (size / 1024).toFixed(size < 10240 ? 1 : 0) + " KiB",
                        age: age < 90 ? "now" : (age < 5400 ? Math.round(age / 60) + "m"
                              : (age < 172800 ? Math.round(age / 3600) + "h" : Math.round(age / 86400) + "d"))
                    });
                }
                out.sort(function (a, b) {
                    if (a.pinned !== b.pinned)
                        return a.pinned ? -1 : 1;
                    return b.mtime - a.mtime;
                });
                root.notes = out;

                // A note deleted under us must not leave the editor on a ghost slug.
                if (root.currentSlug && !root.hasSlug(root.currentSlug))
                    root.select(out.length ? out[0].slug : "");
            }
        }
    }

    function hasSlug(slug: string): bool {
        for (var i = 0; i < root.notes.length; i++)
            if (root.notes[i].slug === slug)
                return true;
        return false;
    }

    /**
     * The scan hands back a preview with its line breaks and tabs already flattened
     * to spaces; this collapses the runs that leaves behind, so a card shows wrapped
     * prose rather than the ragged indent it had on disk.
     */
    function squeeze(text: string): string {
        return (text || "").replace(/ +/g, " ").trim();
    }

    /**
     * The deck's lead line for a note. A line that opens with `#` is a heading by
     * its mark; otherwise a short first line above a real body reads like one. A
     * long first line is prose, and stays in the preview instead of being relabeled.
     */
    function headingOf(first: string, rest: string): string {
        var h = (first || "").replace(/^#+\s*/, "").trim();
        if (h && h !== first)
            return h;
        if (h && rest && h.length <= 64)
            return h;
        return "";
    }

    /**
     * True when a note holds nothing worth keeping. The title is the filename, so
     * the body is the only thing that can be empty — which is what makes "never
     * written on" and "left blank" the same test.
     */
    function isEmpty(slug: string): bool {
        if (!slug)
            return true;
        if (slug === root.currentSlug)
            return root.draft.trim() === "";
        for (var i = 0; i < root.notes.length; i++)
            if (root.notes[i].slug === slug)
                return root.notes[i].sizeLabel === "0 B";
        return false;
    }

    /**
     * Make `title` safe to use as a filename: no path separators, no leading
     * dot, no control characters, and never empty. Returns "" for input that
     * cannot become a name at all, which callers treat as a rejected create.
     */
    function sanitize(title: string): string {
        var s = (title || "").replace(/[\/\\\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ").trim();
        while (s.startsWith("."))
            s = s.substring(1).trim();
        if (s.length > 96)
            s = s.substring(0, 96).trim();
        return s;
    }

    /**
     * Create an empty note and select it. Returns the slug, or "" if the title
     * sanitizes to nothing. An existing slug is selected rather than clobbered.
     */
    function create(title: string): string {
        var slug = root.sanitize(title);
        if (!slug)
            return "";
        if (root.hasSlug(slug)) {
            root.select(slug);
            return slug;
        }
        //* Seed the list with the note before its file exists, and select it now.
        //* Waiting for `onExited` to scan meant the caller's very next statement —
        //* `focusBody()` — still saw an empty list and no selection, so the caret
        //* never reached the body, and the caller's own `scan()` could land first
        //* and select some *other* note. The entry carries `mtime: 0` so it sorts
        //* newest-first, which is where a just-created note belongs.
        root.notes = root.notes.concat([{
            slug: slug,
            title: slug,
            path: root.notesDir + "/" + slug + root.ext,
            pinned: root.pins[slug] === true,
            mtime: Date.now() / 1000,
            heading: "",
            preview: "",
            sizeLabel: "0 B",
            age: "now"
        }]);
        root.currentSlug = slug;
        root.draft = "";
        root.dirty = false;
        //* Push the empty body through the same load path every other selection uses,
        //* or the editor keeps rendering the *previous* note's text under the new
        //* name (the TextArea only ever receives bodies via onBodyLoaded). Bump the
        //* read token too, so a cat still in flight from a note opened moments ago
        //* cannot land on this fresh, still-empty buffer.
        root.readToken++;
        root.bodyLoaded(slug, "");
        //* The seeded entry is enough to draw and select; the file is only needed so
        //* the note survives a restart. So no select() and no rescan here: both would
        //* race the caller, which focuses the body on the very next statement, and a
        //* rescan landing first would re-select the *old* note and put a different
        //* note's text under the caret. The scan is left to the write path, which
        //* already runs one.
        mkProc.pending = slug;
        mkProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && : > \"$1/$2.md\"",
            "_", root.notesDir, slug];
        mkProc.running = true;
        return slug;
    }

    Process {
        id: mkProc
        property string pending: ""
        /**
         * Nothing to do on success: the note is already in the list and already
         * selected. An empty `: >` file is 0 B either way, and its own mtime lands
         * within the same second as the seeded entry, so the next scan agrees.
         */
        onExited: function (exitCode) {}
    }

    /**
     * Switch to `slug` and pull its body. The read is guarded by a token so a
     * slow cat for a previously selected note cannot land on top of the current
     * draft — the only place in this file where ordering is load-bearing.
     */
    function select(slug: string) {
        //* No `slug === currentSlug` early-out. It was here to avoid a pointless read
        //* when the deck re-selects what is already open, but it also swallowed the
        //* body load that follows a create — leaving the editor on the *previous*
        //* note's text under the new note's name. A repeat `cat` of a note already on
        //* screen costs a process spawn and is always correct; this bug was not.
        root.currentSlug = slug;
        root.draft = "";
        root.dirty = false;
        if (!slug)
            return;
        root.readToken++;
        readProc.token = root.readToken;
        readProc.epoch = root.editEpoch;
        readProc.command = ["sh", "-c", "cat -- \"$1\" 2>/dev/null || true", "_", root.pathFor(slug)];
        readProc.running = true;
    }

    property int readToken: 0

    Process {
        id: readProc
        property int token: 0
        property int epoch: 0
        stdout: StdioCollector {
            onStreamFinished: {
                //* Drop the result if this note was reselected since, or if the user
                //* typed while the read was in flight. Either way the buffer is newer.
                if (readProc.token !== root.readToken || readProc.epoch !== root.editEpoch)
                    return;
                root.draft = this.text;
                root.dirty = false;
                root.bodyLoaded(root.currentSlug, this.text);
            }
        }
    }

    function pathFor(slug: string): string {
        return slug ? root.notesDir + "/" + slug + root.ext : "/dev/null";
    }

    /**
     * Write the draft through a temp file and rename it over the note, so a
     * crash mid-save cannot truncate an existing note into a half-written one.
     */
    function save() {
        if (!root.currentSlug || !root.dirty)
            return;
        // A Process already running swallows a new `running = true`, so a save
        // landing mid-write would be dropped and the buffer would stay dirty
        // forever. Latch instead and re-fire from onExited.
        if (writeProc.running) {
            saveQueued = true;
            return;
        }
        writeProc.written = root.draft;
        writeProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/.ukisave\" && mv -f \"$1/.ukisave\" \"$1/$3.md\"",
            "_", root.notesDir, root.draft, root.currentSlug];
        writeProc.running = true;
    }

    property bool saveQueued: false

    Process {
        id: writeProc
        /** The exact draft handed to the shell, so keystrokes typed mid-save stay dirty. */
        property string written: ""
        onExited: function (exitCode) {
            if (exitCode !== 0)
                return;
            // Only clear dirty if the buffer still matches what landed on disk;
            // anything typed while the write was in flight needs another pass.
            if (root.draft === writeProc.written)
                root.dirty = false;
            root.scan();
            if (root.saveQueued) {
                root.saveQueued = false;
                root.save();
            }
        }
    }

    /**
     * Delete a note and its pin, and leave nothing selected.
     *
     * This used to pick a neighbour on the rescan so the editor could never empty
     * silently — which meant a delete from the note page silently reopened a
     * different note, and the user never saw the pad they thought they'd deleted
     * from. Choosing where to land is the surface's call, not the model's: the
     * note page returns to the deck, the deck stays on the deck.
     */
    function remove(slug: string) {
        if (!slug)
            return;
        if (root.currentSlug === slug) {
            root.currentSlug = "";
            root.draft = "";
            root.dirty = false;
        }
        rmProc.command = ["sh", "-c", "rm -f -- \"$1\"", "_", root.pathFor(slug)];
        rmProc.running = true;
        root.dropPin(slug);
    }

    Process {
        id: rmProc
        onExited: root.scan()
    }

    /**
     * Rename by renaming the file. Refuses a target that already exists rather
     * than clobbering it, and refuses an unchanged or empty slug.
     */
    function rename(fromSlug: string, toTitle: string): bool {
        var slug = root.sanitize(toTitle);
        if (!slug || slug === fromSlug)
            return false;
        if (root.hasSlug(slug))
            return false;
        mvProc.pending = slug;
        mvProc.pendingFrom = fromSlug;
        mvProc.command = ["sh", "-c", "mv -f -- \"$1/$2.md\" \"$1/$3.md\"",
            "_", root.notesDir, fromSlug, slug];
        mvProc.running = true;
        return true;
    }

    Process {
        id: mvProc
        property string pending: ""
        property string pendingFrom: ""
        onExited: function (exitCode) {
            if (exitCode !== 0)
                return;
            var to = mvProc.pending;
            var from = mvProc.pendingFrom;
            if (root.currentSlug === from) {
                root.currentSlug = "";
                root.select(to);
            }
            if (root.pins[from] === true) {
                root.dropPin(from);
                root.setPin(to, true);
            }
            root.scan();
        }
    }

    /** Empty the current note's body without deleting the note itself. */
    function clearBody() {
        if (!root.currentSlug)
            return;
        root.draft = "";
        root.dirty = true;
        //* Push the emptied buffer through the same load path, or the editor keeps
        //* rendering the old text while the model already holds an empty note.
        root.bodyLoaded(root.currentSlug, "");
        root.save();
    }

    function loadPins() {
        var raw = pinStore.text();
        try {
            var v = raw && raw.length > 0 ? JSON.parse(raw) : {};
            root.pins = (v && typeof v === "object" && !Array.isArray(v)) ? v : {};
        } catch (e) {
            root.pins = {};
        }
    }

    function savePins() {
        pinStore.setText(JSON.stringify(root.pins));
    }

    function setPin(slug: string, on: bool) {
        if (!slug)
            return;
        var next = {};
        for (var k in root.pins)
            if (root.pins[k] === true)
                next[k] = true;
        if (on)
            next[slug] = true;
        else
            delete next[slug];
        root.pins = next;
        root.savePins();
        //* `pinned` on a note entry is stamped by the scan, and nothing else builds
        //* those entries. Without this rescan the pin map is correct but every card
        //* and the header glyph still read the pre-toggle value, so the click looked
        //* like it had done nothing.
        root.scan();
    }

    function togglePin(slug: string) {
        root.setPin(slug, root.pins[slug] !== true);
    }

    function dropPin(slug: string) {
        if (root.pins[slug] === true)
            root.setPin(slug, false);
    }
}
