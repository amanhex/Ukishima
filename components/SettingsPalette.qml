pragma ComponentBehavior: Bound

import QtQuick

/**
 * The colour contract a settings surface hands to the rows it contains.
 *
 * The row widgets used to reach straight into the pill's `Theme` singleton, which
 * pinned every settings page to the pill's palette: the dock's settings could not
 * be anything but a recoloured copy of a pill surface, and a theme change moved
 * both at once. A palette object is the seam. `SettingsSurface` publishes the
 * pill's tokens; the dock's own settings panel publishes the dock's. The rows
 * read whichever they are given, so the same `SettingsRow` renders either host
 * and neither can reach the other's colours.
 *
 * Every slot is a real colour rather than an optional one, so a host that
 * forgets a slot shows the mistake instead of silently inheriting the pill.
 */
QtObject {
    id: pal

    /** Primary text, and a row icon while its row is focused. */
    property color ink: "#ff00ff"
    /** Secondary text: a row's resting icon, a segment's unselected label. */
    property color sub: "#ff00ff"
    /** Tertiary text: sub-captions, placeholders, hints. */
    property color faint: "#ff00ff"
    /** De-emphasised copy, one step below `faint`. */
    property color dim: "#ff00ff"
    /** Row backdrop on hover/focus, and a segment's unselected backdrop. */
    property color tile: "#ff00ff"
    /** The hairline capping a row. */
    property color hair: "#ff00ff"
    /** Outline for a control at rest (a toggle's off border). */
    property color edge: "#ff00ff"
    /** Ink that sits on top of the accent (a toggle's knob, accent-filled text).
     *  Not named `onAccent`: QML would read an `on`-prefixed property as a
     *  handler for the matching change signal and refuse to compile. */
    property color accentInk: "#ff00ff"
    /** The accent, lit — the selected segment's tint and the toggle's fill. */
    property color accent: "#ff00ff"
    /** Panel fill, top and bottom, for a host that paints its own backdrop. */
    property color paneTop: "#ff00ff"
    property color paneBot: "#ff00ff"
}
