pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"

/**
 * The DOCK's own settings surface: the dock's counterpart to `SettingsSurface`,
 * and the reason that file could be reduced to the pill's appearance.
 *
 * The dock's settings used to be a pill sub-surface, which tied three things
 * together that have nothing to do with each other: where the settings were
 * drawn (inside the pill), how they looked (the pill's margins, its glowing row
 * seam, and the pill's `Theme` palette), and how they were opened (an entry in
 * the pill's own surface stack). Changing any of the pill's interface settings
 * therefore changed the dock's, and the dock could not have settings of its own
 * without a second copy of all of it.
 *
 * This is the second host, and it shares only what is genuinely shared:
 *
 *   - `SettingsRows` for the registry, the keyboard cursor and the click/hover
 *     routing — the behaviour, which is host-agnostic.
 *   - `SettingsRow`/`SettingsSeg`/`LinkToggle`/`SettingsHeader` for the row
 *     chrome, which reads whichever palette it is handed.
 *
 * Everything else is the dock's own: it is NOT a `PillSurface`, so it carries
 * no pill margins and no morph, it paints its own backdrop from the dock's
 * palette, and its focus indicator is the focused row's own backdrop rather than
 * the pill's flame seam. The shell places it as a sibling of the dock bar and the
 * dock's gear chip opens it, so the pill's surface stack does not mention it.
 *
 * `pal` is supplied by the host (DockBar), which owns the dock's palette. A
 * panel never derives colours itself, so there is exactly one place where the
 * dock's colours are decided.
 */
Item {
    id: root

    property real s: 1
    property bool open: false

    /** The dock's palette, handed down by the host that owns it. */
    property var pal: null

    /** The row registry, assigned by the deriving page. */
    property var rows: []

    /**
     * Dismissal is NOT the panel's business.
     *
     * This used to carry a `pointerInside` hover watch, and the host asked it
     * whether the pointer was still over the panel before closing. That is gone,
     * and the reason is worth keeping in mind before putting anything like it
     * back: the panel is opened from the gear, which is on the BAR, so on the
     * ordinary path the pointer never crosses the panel at all. A host that
     * requires "the pointer was over the panel" before it will dismiss therefore
     * vetoes the exact case it appears to be guarding, and fires only when the
     * pointer happens to have travelled through the panel on its way elsewhere.
     *
     * The host decides instead, from the block it already measures: the panel
     * and the bar are one input region, `hovered` reads as "over either", and
     * the bar's existing leave-grace closes this. See `dismissBase` in
     * shell.qml and `revealTimer` in DockBar.
     */

    /*
     * implicitWidth / implicitHeight are Item's OWN, deliberately not shadowed
     * by re-declared copies. A host that hosts this in a Loader depends on them:
     * a Loader sizes a loaded item to its own width, so a host that reads
     * `item.width` and feeds it back pins the two at zero, while the implicit
     * pair is the sizing contract that actually works. The page assigns them.
     */

    signal requestClose()

    /**
     * The behaviour, shared with the pill. `active` mirrors `open` so closing
     * the panel drops the keyboard cursor and the next open starts clean rather
     * than resuming mid-list.
     */
    readonly property SettingsRows nav: SettingsRows {
        active: root.open
        rows: root.rows
    }

    readonly property Item focusRowItem: nav.focusRowItem
    readonly property int kbIndex: nav.kbIndex

    function reportRowHover(item, hovered) { nav.reportRowHover(item, hovered); }
    function activateRow(item) { nav.activateRow(item); }

    /**
     * Height and width follow the page, and the page owns both implicit sizes.
     * Repeating them here rather than shadowing the properties keeps a host's
     * Loader in step with the page instead of deadlocking against it.
     */
    height: implicitHeight
    width: implicitWidth

    enabled: open
    opacity: open ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
    }

    /**
     * The dock's backdrop. Deliberately its own slab rather than the pill's
     * body: the same rounded gradient, hairline and drop shadow the dock's own
     * bar uses, so the panel reads as part of the dock, but sized and coloured
     * from the dock's palette.
     */
    Rectangle {
        id: pane
        anchors.fill: parent
        radius: 16 * root.s
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.pal ? root.pal.paneTop : "transparent" }
            GradientStop { position: 1.0; color: root.pal ? root.pal.paneBot : "transparent" }
        }
        border.width: 1
        border.color: root.pal ? root.pal.edge : "transparent"

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 1.0
            shadowVerticalOffset: 10 * root.s
        }

        /** The same upper sheen the bar carries, so the two read as one material. */
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.42
            radius: pane.radius - 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(root.pal ? root.pal.ink : "transparent", 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    /**
     * The page. The dock's settings are ONE page, not a stack: there is no
     * `requestSurface` to route, so a row navigates by changing the panel's own
     * state instead of by asking the host for another page. What used to be the
     * separate app-picker page is a section inside this one.
     */
    default property alias content: page.data

    Item {
        id: page
        anchors.fill: parent
    }
}
