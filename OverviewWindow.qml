pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"
import "Singletons"

/**
 * The overview's window: full-screen, on the overlay layer, holding one grid.
 *
 * Named `OverviewWindow` rather than `Overview` because the host scope in the
 * config root is already `Overview.qml`, and a same-directory `Overview { }`
 * inside it resolves to itself — "Overview is instantiated recursively".
 *
 * It is a `PanelWindow` rather than a pill surface. Tide Island's grid is
 * `rows` × `columns` of screen replicas — about 1830×400 at 2×5 on a 1080p
 * panel — and the pill is a top-anchored strip whose surfaces grow downward from
 * a centred anchor. A grid that size does not fit inside one, so the overview is
 * a sibling of the polkit agent rather than of the mixer.
 *
 * `WlrLayershell.keyboardFocus` is bound to `showing` in both directions: a
 * permanent `Exclusive` would hold the keyboard even while the grid is
 * invisible and break every other surface, and the default is `None`.
 */
PanelWindow {
    id: root

    required property var modelData

    property bool open: false
    property bool previewsEnabled: open

    readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1

    /**
     * Only the focused monitor shows the grid. On one monitor this is always
     * true; on several it stops the grid appearing on every screen at once —
     * the same guard the polkit dialog uses.
     */
    readonly property bool isFocused: Hyprland.focusedMonitor
        ? Hyprland.focusedMonitor.name === modelData.name
        : true

    readonly property bool showing: open && isFocused

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ukishima-overview"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    /**
     * Input region: the whole screen while the grid is up, **nothing at all**
     * the rest of the time.
     *
     * This window is created for every screen the day the shell starts and then
     * stays mapped for the shell's whole lifetime — `Overview.qml` mounts one
     * instance per screen up front and only flips `open` on them — and it is a
     * full-screen `Overlay` surface created *after* the pill's and the dock's, so
     * on the Overlay layer it sits above both of them. A layer surface with no
     * mask takes its whole rectangle as input, and Qt Quick never passes an
     * unhandled press down to the surfaces below: a transparent, empty, invisible
     * grid kept swallowing every click on the desktop, on the pill's surfaces and
     * on the dock, for as long as the shell ran.
     *
     * `hiddenRegion` is empty on purpose — that is what makes the input region
     * empty, so the compositor skips this surface for hit testing and the click
     * lands on whatever is really underneath. Same trick, and same reason, as the
     * pill, the dock and both reserve strips in `shell.qml` (`hiddenRegion`,
     * `emptyReserve`, `emptyDockReserve`): a full-screen overlay that never narrows
     * itself is a full-screen click trap.
     */
    mask: showing ? fullRegion : hiddenRegion
    Region { id: hiddenRegion }

    Region {
        id: fullRegion
        width: root.width
        height: root.height
    }

    /**
     * `Walls.current` may name a video — ukishima plays mp4/webm through
     * mpvpaper — and `Image` cannot decode those, so a video wallpaper leaves
     * the cells on their solid fill rather than showing a broken-image box.
     */
    readonly property string wallpaperSource: {
        const p = Walls.current;
        if (!p || p.length === 0)
            return "";
        if (/\.(mp4|webm|mkv|mov|avi)$/i.test(p))
            return "";
        return p.indexOf("file://") === 0 ? p : "file://" + p;
    }

    //* Dim the desktop behind the grid.
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        visible: root.showing
    }

    OverviewLayer {
        id: layer
        anchors.centerIn: parent
        screen: root.modelData
        showCondition: root.showing
        previewsEnabled: root.previewsEnabled
        wallpaperSource: root.wallpaperSource
        onCloseRequested: root.requestClose()
    }

    //* Take the keyboard as soon as the grid is up: the keybind that opened it
    //* released immediately, and without this the first arrow key goes to the
    //* window underneath.
    onShowingChanged: {
        if (showing)
            layer.grabKeyboardFocus();
    }

    signal requestClose()
}
