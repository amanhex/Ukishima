pragma ComponentBehavior: Bound

import QtQuick

/**
 * The behaviour behind a settings surface's rows, with no visual opinion at
 * all: the row registry, the keyboard cursor, and the routing of hover, clicks
 * and Enter into whatever each row's control kind does.
 *
 * This used to live inside `SettingsSurface`, which meant the behaviour could
 * only be had by extending a PillSurface — so the dock's settings had to be a
 * pill surface, and any change to how the pill's settings looked or morphed
 * landed on the dock too. Splitting the behaviour out lets a second host give
 * the same rows a completely different appearance: `SettingsSurface` keeps the
 * pill's morphology and the glowing row seam, and the dock's own settings
 * surface will bind these same functions to its own chrome.
 *
 * A `rows` entry pairs a row item with its control kind and the backing getter
 * and setter: `seg` cycles a segmented choice (wrapping), `toggle` flips a
 * boolean, `nav` asks the host to open another surface. Hosts route arrow keys
 * through `kbMove`, `kbAdjust` and `kbActivate`; hover and clicks route through
 * `reportRowHover` and `activateRow`, keeping `kbIndex` and the focus in sync.
 */
QtObject {
    id: root

    /** Mirrors the host surface's `active`, so closing a surface drops the
     *  cursor and the next open starts clean rather than resuming mid-list. */
    property bool active: true

    /** The host's row registry. Assigned by the host, never bound. */
    property var rows: []

    /** The row the cursor is on, or null. Hosts read this to paint focus. */
    property Item focusRowItem: null

    /** Index into `rows` of the focused row, or -1. */
    property int kbIndex: -1

    /** Raised when a `nav` row is activated; the host decides what to open. */
    signal requestSurface(string name)

    onActiveChanged: if (!active) {
        root.closeMenus(null);
        root.clear();
    }

    // A row can leave the list while the nav is sitting on it: the lock's
    // "Avatar image" row only exists while the avatar is on, so flipping that
    // toggle shortens `rows` underneath the cursor. kbIndex is then either past
    // the end — where kbMove would throw on `rows[kbIndex].item` — or pointing
    // at a row that is simply not on screen, which drags the focus seam down to
    // a gap in the list. Dropping focus is the honest answer: the thing that
    // was focused is gone. The next arrow press picks a real row back up.
    onRowsChanged: {
        if (root.kbIndex >= root.rows.length
            || (root.focusRowItem !== null && root.rowIndexOf(root.focusRowItem) < 0))
            root.clear();
    }

    function clear() {
        root.focusRowItem = null;
        root.kbIndex = -1;
    }

    function rowIndexOf(item) {
        for (var i = 0; i < root.rows.length; i++)
            if (root.rows[i].item === item)
                return i;
        return -1;
    }

    /** Step a seg row's value by `dir`, wrapping at both ends like a mouse click. */
    function segCycle(r, dir) {
        var n = r.vals.length;
        var i = r.vals.indexOf(r.get());
        r.set(r.vals[(((i < 0 ? 0 : i) + dir) % n + n) % n]);
    }

    function kbMove(dir) {
        if (!root.rows.length)
            return;
        root.kbIndex = Math.max(0, Math.min(root.rows.length - 1, (root.kbIndex < 0 ? 0 : root.kbIndex + dir)));
        root.focusRowItem = root.rows[root.kbIndex].item;
    }

    function kbAdjust(dir) {
        if (!root.rows.length)
            return;
        if (root.kbIndex < 0) {
            root.kbIndex = 0;
            root.focusRowItem = root.rows[0].item;
        }
        var r = root.rows[root.kbIndex];
        if (r.kind === "seg")
            root.segCycle(r, dir);
        else if (r.kind === "toggle")
            r.set(dir > 0);
    }

    function kbActivate() {
        if (root.kbIndex < 0)
            return;
        var r = root.rows[root.kbIndex];
        if (r.activate)
            r.activate();
        else if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg")
            root.segCycle(r, 1);
    }

    /**
     * Close every row's open dropdown menu — the wallpaper strip's job for a
     * modal click-away scrim, done per row here: a click on any other row is
     * the click-away. `except` (the row being clicked) keeps its own menu.
     */
    function closeMenus(except) {
        for (var i = 0; i < root.rows.length; i++) {
            var row = root.rows[i].item;
            if (row === undefined || row === except)
                continue;
            var ctl = row.control;
            if (ctl === undefined || ctl.length === undefined)
                continue;
            for (var j = 0; j < ctl.length; j++)
                if (ctl[j].open)
                    ctl[j].open = false;
        }
    }

    /**
     * A click anywhere on a row drives its control: toggles flip, nav rows open
     * their surface, and segmented rows step to the next value (wrapping). The
     * control's own hit areas stay on top, so clicking a specific segment still
     * picks it directly.
     */
    function activateRow(item) {
        root.closeMenus(item);
        var idx = root.rowIndexOf(item);
        if (idx < 0)
            return;
        root.kbIndex = idx;
        root.focusRowItem = item;
        var r = root.rows[idx];
        if (r.activate)
            r.activate();
        else if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg")
            root.segCycle(r, 1);
    }

    function reportRowHover(item, hovered) {
        if (hovered) {
            root.focusRowItem = item;
            root.kbIndex = root.rowIndexOf(item);
        }
    }
}
