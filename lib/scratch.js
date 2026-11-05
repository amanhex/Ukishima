/**
 * Navigation shared by the four scratchpad designs (Cassette, Console, Index,
 * Ash). They each walked the note list to find the current slug, then opened or
 * deleted whatever their cursor pointed at; only the cursor property differed.
 * The note list and the host are passed in because an imported JS file cannot
 * reach QML singletons or types.
 */

/** Cursor index for the note matching `slug`, or a clamped `current` if gone. */
function locate(notes, slug, current) {
    for (var i = 0; i < notes.length; i++)
        if (notes[i].slug === slug) return i;
    return current >= notes.length ? Math.max(0, notes.length - 1) : current;
}

/** The note at `index`, or null when the cursor sits on an empty list. */
function noteAt(notes, index) {
    return notes[index] || null;
}

/** Open the note under the cursor, or the create view when there is none. */
function open(host, notes, index) {
    var note = noteAt(notes, index);
    if (note) host.openNote(note.slug);
    else host.openCreate();
}

/** Delete the note under the cursor; no-op on an empty list. */
function remove(scratch, notes, index) {
    var note = noteAt(notes, index);
    if (note) scratch.remove(note.slug);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { locate, noteAt, open, remove };
}
