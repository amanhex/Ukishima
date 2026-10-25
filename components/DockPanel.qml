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
 * no pill margins, it paints its own backdrop from the dock's palette, and its
 * focus indicator is the focused row's own backdrop rather than the pill's
 * flame seam. The shell places it as a sibling of the dock bar and the dock's
 * gear chip opens it, so the pill's surface stack does not mention it. It gets
 * its own small fade/slide on open, close and page swap, timed by the dock's
 * Motion setting.
 *
 * `pal` is supplied by the host (DockBar), which owns the dock's palette. A
 * panel never derives colours itself, so there is exactly one place where the
 * dock's colours are decided.
 *
 * Sub-page navigation: a page can emit `requestSurface(name)` to ask the host
 * to switch to another dock settings page (e.g. "dockBehavior", "dockAppearance").
 * The host (shell.qml) owns the page stack and handles the signal.
 */
Item {
    id: root

    property real s: 1
    property bool open: false

    /** The dock's palette, handed down by the host that owns it. */
    property var pal: null

    /** Name of the surface to navigate back to when the header back chevron is clicked. */
    property string backSurface: ""

    /** Padding values for the panel content, scaled by `s`. */
    readonly property real padTop: 14
    readonly property real padBottom: 12
    readonly property real padLeft: 16

    /** The panel's own width, before scale. A page never decides it. */
    readonly property real panelW: 400
    implicitWidth: panelW * root.s

    /** Shorthands for this surface's own colour lookups from `pal`. */
    readonly property color ink: root.pal ? root.pal.ink : "white"
    readonly property color faint: root.pal ? root.pal.faint : "gray"
    readonly property color dim: root.pal ? root.pal.dim : "gray"
    readonly property color accent: root.pal ? root.pal.accent : "gray"
    readonly property color tile: root.pal ? root.pal.tile : "transparent"

    /**
     * Names this window to the centred picker: every `Dropdown` under the dock
     * reports it so the picker is drawn by the dock's own window and not the
     * pill's. Set by the shell, which knows the monitor.
     */
    property string pickerKey: ""

    /** The row registry, assigned by the deriving page. */
    property var rows: []

    /**
     * Dismissal is NOT the panel's business. The shell keeps a full-screen
     * click floor under it while open, so a click anywhere outside the panel or
     * the bar closes it; Esc and the back chevron are handled above. Hover is
     * deliberately not a dismissal signal: on niri, re-committing the layer
     * input region can synthesize a leave while the pointer is still on the
     * gear, which used to close the panel the instant it opened.
     */

    /*
     * implicitWidth / implicitHeight are Item's OWN, deliberately not shadowed
     * by re-declared copies. A host that hosts this in a Loader depends on them:
     * a Loader sizes a loaded item to its own width, so a host that reads
     * `item.width` and feeds it back pins the two at zero, while the implicit
     * pair is the sizing contract that actually works. The page assigns them.
     */

    signal requestClose()
    signal requestSurface(string name)

    /** Step back one page: to `backSurface` when set, otherwise dismiss. */
    function surfaceBack() {
        if (root.backSurface && root.backSurface.length > 0) {
            root.requestSurface(root.backSurface);
            return;
        }
        root.requestClose();
    }

    /**
     * The behaviour, shared with the pill. `active` mirrors `open` so closing
     * the panel drops the keyboard cursor and the next open starts clean rather
     * than resuming mid-list.
     */
    readonly property SettingsRows nav: SettingsRows {
        active: root.open
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

    /** The panel owns the keyboard while open, so arrows/Enter/Esc reach the rows. */
    focus: true
    Keys.onUpPressed: (e) => { nav.kbMove(-1); e.accepted = true; }
    Keys.onDownPressed: (e) => { nav.kbMove(1); e.accepted = true; }
    Keys.onLeftPressed: (e) => { nav.kbAdjust(-1); e.accepted = true; }
    Keys.onRightPressed: (e) => { nav.kbAdjust(1); e.accepted = true; }
    Keys.onReturnPressed: (e) => { nav.kbActivate(); e.accepted = true; }
    Keys.onEnterPressed: (e) => { nav.kbActivate(); e.accepted = true; }
    Keys.onEscapePressed: (e) => { root.surfaceBack(); e.accepted = true; }

    /** Plays the fade/slide in. A page swap creates a new panel, so this also
     *  covers the sub-page transition. The zero is left on screen for one event
     *  loop turn: setting both values in the same turn as creation gives the
     *  binding no chance to ever read the start state, which is how the first
     *  version ended up appearing instantly. */
    function playIntro() {
        root.opacity = 0;
        root.introOffset = 10;
        Qt.callLater(function() {
            if (!root.open)
                return;
            root.opacity = 1;
            root.introOffset = 0;
        });
    }

    onOpenChanged: {
        if (open) {
            root.forceActiveFocus();
            playIntro();
        } else {
            root.opacity = 0;
            root.introOffset = 10;
        }
    }

    /**
     * Height and width follow the page, and the page owns both implicit sizes.
     * Repeating them here rather than shadowing the properties keeps a host's
     * Loader in step with the page instead of deadlocking against it.
     */
    height: implicitHeight
    width: implicitWidth

    enabled: open

    property real introOffset: 10

    opacity: 0
    visible: opacity > 0.01
    transform: Translate { y: root.introOffset * root.s }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.dockMorph
            easing.type: Motion.dockEase
            easing.bezierCurve: Motion.morphCurve
        }
    }
    Behavior on introOffset {
        NumberAnimation {
            duration: Motion.dockMorph
            easing.type: Motion.dockEase
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Component.onCompleted: if (root.open) root.playIntro()

    /**
     * The dock's backdrop. Deliberately its own slab rather than the pill's
     * body: the same rounded gradient, hairline and drop shadow the dock's own
     * bar uses, so the panel reads as part of the dock, but sized and coloured
     * from the dock's palette.
     *
     * The pane tokens already carry the dock's effective glass alpha, so this
     * stays neutral and palette-matched in both transparent and solid modes.
     * Do not re-tint it from the pill's Theme: vermLit at 30% turned the
     * transparent panel red, and it ignored a forced dock palette.
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
     * The page content. A page declares its Column inside this; the panel owns
     * the insets, so every page lines up with the same pads and no page can
     * drift from the others.
     */
    default property alias content: page.data

    Item {
        id: page
        anchors.fill: parent
        anchors.topMargin: root.padTop * root.s
        anchors.bottomMargin: root.padBottom * root.s
        anchors.leftMargin: root.padLeft * root.s
        anchors.rightMargin: root.padLeft * root.s
    }

    /**
     * The header strip is the back target: it folds to `backSurface`, or closes
     * when this is the index. Sized to the header plus the top pad so it can
     * never steal a click from the first row.
     */
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: (root.padTop + 24) * root.s
        z: 10
        enabled: root.open
        cursorShape: Qt.PointingHandCursor
        onClicked: root.surfaceBack()
    }
}
