pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * The PILL's morphing settings surface: the category index and each
 * sub-surface. Carries the pill morphology (the margins below), the glowing
 * row-soul seam, and morphs back to the parent index when empty space is
 * clicked on a sub-surface. The deriving surface sets `rows`, optionally
 * `backSurface`, and lays out its own content column (header, section labels,
 * SettingsRow lines).
 *
 * The row behaviour — the registry, the keyboard cursor and the click/hover
 * routing — lives in `SettingsRows` and is only forwarded from here, so this
 * file is purely the pill's APPEARANCE. That split is what lets the dock grow
 * its own settings surface with the same behaviour and a different look: a
 * change to the pill's margins or seam no longer reaches anything that is not
 * a pill surface, and vice versa.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    property string backSurface: ""
    signal requestSurface(string name)

    /** The row registry, assigned by the deriving surface. */
    property var rows: []

    /**
     * The PILL's palette, published for the rows it contains. This is the only
     * place the pill's settings colours are resolved, so a row cannot reach past
     * its host: the dock's settings panel publishes the dock's palette under the
     * same name and its rows come out in the dock's colours with no change here.
     */
    readonly property SettingsPalette pal: SettingsPalette {
        ink: Theme.cream
        sub: Theme.subtle
        faint: Theme.faint
        dim: Theme.dim
        tile: Theme.frameBg
        hair: Theme.hairSoft
        edge: Theme.border
        accentInk: Theme.cream
        accent: Theme.verm
    }

    /** The behaviour, shared with any other host that wants it. */
    readonly property SettingsRows nav: SettingsRows {
        active: root.active
        rows: root.rows
        onRequestSurface: (name) => root.requestSurface(name)
    }

    readonly property Item focusRowItem: nav.focusRowItem
    readonly property int kbIndex: nav.kbIndex

    function reportRowHover(item, hovered) { nav.reportRowHover(item, hovered); }
    function activateRow(item) { nav.activateRow(item); }
    function kbMove(dir) { nav.kbMove(dir); }
    function kbAdjust(dir) { nav.kbAdjust(dir); }
    function kbActivate() { nav.kbActivate(); }

    readonly property bool rowFocused: nav.focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void nav.focusRowItem;
        if (!nav.focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return nav.focusRowItem.mapToItem(root, 4 * root.s, nav.focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint
}
