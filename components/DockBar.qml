pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Singletons"

/**
 * macOS-style bottom dock: a floating washi bar showing the pinned apps in
 * their user-chosen order, then a hairline divider, then every running app
 * that is not already pinned. Clicking a running app focuses its window
 * (workspace switch included), clicking a closed one launches its desktop
 * entry; right-click toggles the pin. A window whose class cannot be resolved
 * to a desktop entry still appears while running (icon from the theme) but
 * cannot be pinned, since there is nothing to re-launch.
 *
 * Pins live in the same state file pattern as launcher usage counts
 * (ukishima/dock-pins.json, an ordered JSON array of desktop entry ids), so
 * they survive restarts and are shared by every monitor's dock. The item list
 * is rebuilt on an interval and whenever pins change, because the toplevel
 * model's .values is not reliably notifiable.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""

    /**
     * Reveal collaboration with the shell window: `hovered` is fed by a
     * window-level HoverHandler (pointer events only exist inside the input
     * mask, so "hovered" means "over the revealed strip or the bar"), and
     * `revealSession` is latched while the pointer is over the dock and
     * released on a grace delay after it leaves, exactly like the pill's.
     */
    property bool hovered: false
    property bool revealSession: false

    /** Fed by shell.qml: surface open / monitor fullscreen / game mode. */
    property bool suppressed: false

    readonly property bool hidden: Flags.dockAutoHide && !revealSession && !hovered

    /** The bar is down (retracted or suppressed) and its contents are inert. */
    readonly property bool down: hidden || suppressed

    readonly property bool minimal: Flags.dockMinimal

    /** Inline title row under the icons (full mode only); minimal is icon + dot. */
    readonly property bool titled: !Flags.dockMinimal

    readonly property real dockH: (minimal ? 58 : 68) * s
    readonly property real chipW: (minimal ? 56 : 58) * s
    readonly property int chipSpacing: 2

    // ---- dock palette: the dock resolves its own effective theme, so the pane,
//      copy, hairline and the active/dot accents all come from ONE palette —
//      no global-Theme leaks. The selector mirrors the pill's theme choices
//      (light/dark/dynamic/manual), so the dock is themed independently of the
//      pill. The glass depth is a separate axis: "transparent" lets the desktop
//      glow through at glassAlpha, "solid" paints opaque. ----

/** Effective palette mode, resolved from the dock's own selector. */
    readonly property string dockMode: (Flags.dockTheme === "auto"
        || Flags.dockTheme === "transparent") ? "dark" : Flags.dockTheme
    readonly property bool dockEffDyn: root.dockMode === "dynamic" || root.dockMode === "manual"
    readonly property bool dockEffLight: root.dockMode === "light"
    /**
     * Translucency of the transparent pane, mirroring the pill's regular glass
     * (0.78 * pill opacity). The dock can not lean on the pill's readability
     * veil, so its floor sits a touch higher to keep icon and title contrast.
     */
    readonly property real glassAlpha: Math.max(0.45, Math.min(0.95, 0.78 * (Flags.pillOpacity || 1)))
    /** Legacy or "auto" flag values (pre-split saves) render as the transparent pane. */
    readonly property bool dockGlass: Flags.dockStyle !== "solid"

    /** The palette tokens below mirror Theme.qml's ternaries but resolve from
     *  the dock's own `dockMode` — so a forced dark dock keeps dark text and
     *  a vermilion dot even while the pill sits on a light palette, and the
     *  matched light/dynamic variants stay readable on their own grounds. */
    function blendColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property color dockAccent: root.dockEffDyn ? Dyn.primary : "#ff9a64"
    readonly property color dockActive: root.dockEffDyn ? Dyn.primary : "#e0563b"
    readonly property color dockCardTop: root.dockEffDyn ? Dyn.surfaceContainerHigh
        : (root.dockEffLight ? "#f6f2ec" : "#171717")
    readonly property color dockCardBot: root.dockEffDyn ? Dyn.surfaceContainerLow
        : (root.dockEffLight ? "#ece6df" : "#0c0c0c")
    readonly property color dockCream: root.dockEffDyn ? Dyn.cream
        : (root.dockEffLight ? "#2a241f" : "#ececec")
    readonly property color dockPaneTop: root.dockGlass
        ? Qt.alpha(root.blendColor(root.dockCardTop, root.dockAccent, 0.05), root.glassAlpha)
        : root.blendColor(root.dockCardTop, root.dockAccent, 0.05)
    readonly property color dockPaneBot: root.dockGlass
        ? Qt.alpha(root.blendColor(root.dockCardBot, root.dockAccent, 0.03), root.glassAlpha)
        : root.blendColor(root.dockCardBot, root.dockAccent, 0.03)
    readonly property color dockBorder: root.dockEffLight
        ? Qt.alpha("#000000", 0.12) : Qt.alpha("#ffffff", 0.14)
    readonly property color dockSheen: root.dockEffLight
        ? Qt.alpha("#ffffff", 0.22) : Qt.alpha("#ffffff", 0.07)
    readonly property color dockHighlight: root.dockEffLight
        ? Qt.alpha("#1c1a17", 0.08) : Qt.alpha("#ffffff", 0.12)
    readonly property color dockDotIdle: root.dockEffLight
        ? Qt.alpha("#2c2926", 0.72) : Qt.alpha("#e4e2e8", 0.72)
    readonly property color dockCopy: root.dockEffLight ? "#3b3833" : "#cfcdd4"
    readonly property color dockFaint: root.dockEffLight
        ? Qt.alpha("#3b3833", 0.6) : Qt.alpha("#cfcdd4", 0.55)
    readonly property color dockHair: Qt.alpha(root.dockCream, 0.08)
    readonly property color dockDim: Qt.rgba(0, 0, 0, 0.45)

    property var pins: DockPins.pins
    property var items: []

    /** Multi-window preview: one chip's hover popover. The shell window keeps
     *  its input band live while the bar is up, so no per-preview geometry
     *  needs reporting; previewOpen only gates the always-on-dock band. */
    property bool previewOpen: false

    width: slab.width
    height: dockH

    onHoveredChanged: {
        if (root.hovered) {
            revealTimer.stop();
            root.revealSession = true;
        } else {
            revealTimer.start();
        }
    }

    Timer {
        id: revealTimer
        interval: 350
        onTriggered: { if (!root.hovered) root.revealSession = false; }
    }

    Timer {
        id: itemsTimer
        interval: 800
        repeat: true
        running: Flags.dockEnabled
        onTriggered: root.refreshItems()
    }

    Connections {
        target: DockPins
        function onPinsChanged() { root.refreshItems(); }
    }

    Component.onCompleted: root.refreshItems()

    /**
     * Only rebuild when the underlying state actually changed. The model is a
     * fresh array of fresh objects each build, so reassigning it makes the
     * Repeater destroy and recreate every chip delegate — which drops hover
     * state and closes an open preview. Without this guard the 800ms poll
     * would do that on every tick.
     */
    property string itemSig: ""
    function refreshItems() {
        var sig = root.itemsSignature();
        if (sig === root.itemSig) return;
        root.itemSig = sig;
        root.items = buildItems();
    }

    function itemsSignature() {
        var s = "";
        var tls = Hyprland.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i];
            if (t && t.workspace)
                s += root.classOf(t) + ":" + t.address
                    + (t.activated ? ":1" : ":0") + ";";
        }
        for (var j = 0; j < root.pins.length; j++)
            s += "P:" + root.pins[j] + ";";
        return s;
    }

    /**
     * The window-class -> desktop-entry bridge: prefer the raw class match
     * (firefox fires) and fall back to the final dotted segment so namespaced
     * ids like org.wezfurlong.wezterm still resolve against a "wezterm" class.
     */
    function entryFor(cls) {
        if (!cls) return null;
        var q = cls.toLowerCase();
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === q)
                return e;
        }
        var dot = q.lastIndexOf(".");
        if (dot >= 0) {
            var tail = q.substring(dot + 1);
            for (var j = 0; j < apps.length; j++) {
                var e2 = apps[j];
                if (e2 && e2.id && e2.id.toLowerCase() === tail)
                    return e2;
            }
        }
        return null;
    }

    /** Resolve a persisted pin by entry id, tolerating a .desktop suffix. */
    function entryById(id) {
        if (!id) return null;
        var q = id.toLowerCase();
        if (q.endsWith(".desktop")) q = q.slice(0, -8);
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === q)
                return e;
        }
        return null;
    }

    function classOf(t) {
        return (t && t.lastIpcObject && t.lastIpcObject.class) ? t.lastIpcObject.class
            : (t && t.wayland && t.wayland.appId) ? t.wayland.appId : "";
    }

    function anyActive(ws) {
        for (var i = 0; i < ws.length; i++)
            if (ws[i] && ws[i].activated) return true;
        return false;
    }

    /**
     * Workspace number for a window, read from its workspace name: names are
     * "1", "2".. or "N:label" — the Quickshell toplevel's workspace object only
     * ever reports id = -1, so the leading integer of the name is the usable
     * key. Returns a sentinel for special workspaces and unnameable windows,
     * so those sort after every numbered workspace.
     */
    function wsNum(w) {
        if (!w || !w.workspace) return 2000000000;
        var nm = String(w.workspace.name || "");
        var m = /^(\d+)/.exec(nm);
        return m ? parseInt(m[1], 10) : 2000000000;
    }

    /** Lowest numbered workspace among the windows (special workspaces ignored). */
    function minWs(windows) {
        var m = 2000000000;
        for (var i = 0; i < windows.length; i++) {
            var n = root.wsNum(windows[i]);
            if (n < m) m = n;
        }
        return m;
    }

    function iconForName(name) {
        if (!name || name.length === 0) return "";
        if (name.charAt(0) === "/") return "file://" + name;
        if (Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name, "application-x-executable");
        return "";
    }

    function buildItems() {
        var out = [];
        var byClass = {};
        var order = [];
        var tls = Hyprland.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i];
            if (!t || !t.workspace) continue;
            var cls = root.classOf(t);
            if (!cls) continue;
            var key = cls.toLowerCase();
            if (!byClass[key]) { byClass[key] = []; order.push(key); }
            byClass[key].push(t);
        }

        // Resolve every live class to a desktop entry once, then index the
        // reverse map (entry id -> class keys) so a pinned entry picks up all
        // of its window classes, not just the exact id match.
        var classEntry = {};
        var entryKeys = {};
        for (var o = 0; o < order.length; o++) {
            var k = order[o];
            var e = root.entryFor(k);
            classEntry[k] = e;
            var ek = e && e.id ? e.id.toLowerCase() : "";
            if (ek) {
                if (!entryKeys[ek]) entryKeys[ek] = [];
                entryKeys[ek].push(k);
            }
        }

        function windowsFor(entryId) {
            var keys = entryKeys[entryId] || [entryId];
            var acc = [];
            for (var n = 0; n < keys.length; n++)
                if (byClass[keys[n]]) acc = acc.concat(byClass[keys[n]]);
            return acc;
        }

        var pinnedKeys = [];
        for (var p = 0; p < root.pins.length; p++) {
            var pe = root.entryById(root.pins[p]);
            if (!pe) continue;
            var pk = (pe.id || "").toLowerCase();
            if (pinnedKeys.indexOf(pk) >= 0) continue;
            pinnedKeys.push(pk);
            var ws = windowsFor(pk);
            out.push({
                entry: pe,
                cls: pk,
                name: pe.name,
                pinned: true,
                windows: ws,
                running: ws.length > 0,
                active: root.anyActive(ws)
            });
        }

        var running = [];
        for (var r = 0; r < order.length; r++) {
            var key = order[r];
            var e2 = classEntry[key];
            var w = byClass[key];
            if (e2) {
                var ek2 = (e2.id || "").toLowerCase();
                if (pinnedKeys.indexOf(ek2) >= 0) continue;
                running.push({
                    entry: e2,
                    cls: key,
                    name: e2.name,
                    pinned: false,
                    windows: w,
                    running: true,
                    active: root.anyActive(w),
                    wsSort: root.minWs(w),
                    idx: r
                });
            } else {
                var first = w[0];
                running.push({
                    entry: null,
                    cls: key,
                    name: (first && first.title) ? first.title : key,
                    pinned: false,
                    windows: w,
                    running: true,
                    active: root.anyActive(w),
                    wsSort: root.minWs(w),
                    idx: r
                });
            }
        }

        // Running apps line up by workspace: windows on workspace 1 come first,
        // mirroring Finder's shelf order. Ties keep first-seen order.
        running.sort(function(a, b) {
            if (a.wsSort !== b.wsSort) return a.wsSort - b.wsSort;
            return a.idx - b.idx;
        });

        if (out.length > 0 && running.length > 0)
            out.push({ divider: true });
        return out.concat(running);
    }

    /** Launch a closed app, or focus the best window of a running one. */
    function activate(item) {
        if (!item || item.divider) return;
        if (item.windows.length > 0) {
            root.focusApp(item);
        } else if (item.entry) {
            item.entry.execute();
        }
    }

    /**
     * Focus the app's most relevant window: one parked on this monitor's
     * active workspace wins, otherwise the first non-minimized window. Windows
     * in the special:minimized stash are skipped — those are exactly what the
     * minimize tray restores. Workspaces are compared by name, since a
     * toplevel's workspace object never carries a usable id here.
     */
    function focusApp(item) {
        var wsName = root.activeWsName();
        var best = null;
        var fallback = null;
        for (var i = 0; i < item.windows.length; i++) {
            var w = item.windows[i];
            if (!w || !w.workspace || w.workspace.name === "special:minimized") continue;
            if (!fallback) fallback = w;
            if (wsName && w.workspace.name === wsName) { best = w; break; }
        }
        var t = best || fallback;
        if (!t) return;
        root.focusAddress(t.address);
    }

    /**
     * Raise the window at `address` without moving the pointer. Hyprland's
     * focuswindow warps the cursor to the focused window's centre, so a dock
     * click would teleport the pointer away; toggling cursor:no_warps around
     * this single dispatch suppresses that warp only for this call. The toggle
     * is scoped here — no global config change, everything else keeps warping
     * as configured.
     */
    function focusAddress(addr) {
        if (addr.indexOf("0x") !== 0) addr = "0x" + addr;
        Quickshell.execDetached(["sh", "-c",
            "hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1; " +
            "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + addr + "\" })' >/dev/null 2>&1; " +
            "hyprctl eval 'hl.config({ cursor = { no_warps = false } })' >/dev/null 2>&1",
            "sh"]);
    }

    function activeWsName() {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName && ms[i].activeWorkspace
                && ms[i].activeWorkspace.name)
                return String(ms[i].activeWorkspace.name);
        return Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.name
            ? String(Hyprland.focusedWorkspace.name) : "";
    }

    /**
     * Windows for the hover preview, current-workspace first (mirrors
     * focusApp's preference). Minimized windows are skipped: those live in the
     * special:minimized stash and are restored from the tray instead.
     */
    function orderWindows(windows) {
        var wsName = root.activeWsName();
        var first = [];
        var second = [];
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];
            if (!w || !w.workspace || w.workspace.name === "special:minimized") continue;
            if (wsName && w.workspace.name === wsName) first.push(w); else second.push(w);
        }
        return first.concat(second);
    }

    function togglePin(item) {
        if (!item || item.divider || !item.entry) return;
        DockPins.toggle(item.entry.id);
    }

    // ---- the bar ----

    Rectangle {
        id: slab
        radius: Math.min(20 * s, height / 2)
        width: chips.implicitWidth + 20 * s
        height: root.dockH
        anchors.horizontalCenter: parent.horizontalCenter
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.dockPaneTop }
            GradientStop { position: 1.0; color: root.dockPaneBot }
        }
        border.width: 1
        border.color: root.dockBorder
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.dockDim
            shadowBlur: 1.0
            shadowVerticalOffset: 8 * root.s
        }

        /** Glass top sheen: soft white falloff over the upper third. */
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.42
            radius: slab.radius - 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.dockSheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Row {
        id: chips
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.chipSpacing * root.s

        Repeater {
            model: root.items

            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool divider: !!chip.modelData.divider
                readonly property bool hover: area.containsMouse || panel.containsMouse
                width: chip.divider ? 6 * s : root.chipW
                height: root.dockH

                Rectangle {
                    visible: chip.divider
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 22 * s
                    color: Qt.alpha(root.dockHair, 0.7)
                }

                /**
                 * macOS-style hover: no backdrop box — the icon itself grows
                 * up out of its base (scale origin at the icon's bottom, so it
                 * enlarges toward the top of the dock like the real thing and
                 * never collides with the title/dot below). The resting icon
                 * is one size smaller than it used to be so the hover swell
                 * has room to grow proportionally bigger.
                 */
                Image {
                    visible: !chip.divider
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: (root.titled ? 9 : 12) * s
                    width: (root.titled ? 27 : 32) * s
                    height: (root.titled ? 27 : 32) * s
                    sourceSize.width: Math.round((root.titled ? 54 : 64) * s)
                    sourceSize.height: Math.round((root.titled ? 54 : 64) * s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    transformOrigin: Item.Bottom
                    source: !chip.divider ? root.iconForName(
                        chip.modelData.entry ? chip.modelData.entry.icon : chip.modelData.cls) : ""
                    opacity: !chip.modelData.running && chip.modelData.pinned
                        ? 0.55 : (chip.hover || chip.modelData.active) ? 1 : 0.9
                    /* Magnify up to but never past the dock's top edge: the
                     * icon base sits 36*s (titled) / 44*s (minimal) from the
                     * chip top, so a 1.27 / 1.32 scale still clears the
                     * hairline by ~1.5*s — it never looks like it escapes. */
                    scale: chip.hover ? (root.titled ? 1.27 : 1.32) : 1
                    Behavior on scale { NumberAnimation { duration: Motion.fast } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Text {
                    visible: !chip.divider && root.titled
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20 * s
                    width: parent.width - 6 * s
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: 10 * s
                    font.weight: Font.DemiBold
                    color: root.dockCopy
                    opacity: chip.hover ? 1 : 0.85
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    text: chip.modelData.name
                }

                Rectangle {
                    visible: !chip.divider && chip.modelData.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8 * s
                    width: chip.modelData.active ? 5.5 * s : 4 * s
                    height: chip.modelData.active ? 5.5 * s : 4 * s
                    radius: width / 2
                    color: chip.modelData.active ? root.dockActive : root.dockDotIdle
                    Behavior on width { NumberAnimation { duration: Motion.fast } }
                    Behavior on height { NumberAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    visible: !chip.divider
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton)
                            root.togglePin(chip.modelData);
                        else
                            root.activate(chip.modelData);
                    }
                }

                Tooltip {
                    show: chip.hover && !preview.multi && !chip.divider
                    s: root.s
                    placement: "above"
                    title: chip.divider ? "" : chip.modelData.name
                }

                /**
                 * Multi-window hover preview: a small window picker above the
                 * chip, shown while the app has more than one window (terminal
                 * stacks, browser windows). Clicking a row raises that exact
                 * window with the pointer parked back on the dock. The shell
                 * window's input band stays live while the bar is up, so the
                 * popover takes clicks without any geometry hand-off.
                 */
                Item {
                    id: preview
                    readonly property var wins: chip.modelData && chip.modelData.windows
                        ? root.orderWindows(chip.modelData.windows) : []
                    readonly property bool multi: !chip.divider && wins.length > 1
                    readonly property real pW: 200 * s
                    readonly property real pH: Math.min(wins.length, 5) * (30 * s) + 14 * s
                    readonly property real gap: 9 * s
                    /**
                     * Stays open while the pointer is over the chip OR the panel
                     * itself. The panel mouse area covers the whole item — pane
                     * plus the gap strip below it — so the cursor can walk
                     * straight up out of the chip, across the floating gap and
                     * into the list without dropping the hover mid-way. Never
                     * shows while the dock is retracted (the bar slides the whole
                     * chip out of reach, so `hovered`/`revealSession` would clear
                     * on their own anyway; the !down guard is belt-and-braces
                     * against a stale hover during the slide).
                     */
                    visible: multi && !root.down && (chip.hover || panel.containsMouse)
                    width: pW
                    height: multi ? pH + preview.gap : 0
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    z: 100

                    readonly property int winCount: Math.min(preview.wins.length, 5)
                    readonly property real rowH: 30 * s
                    readonly property real padT: 7 * s

                    /**
                     * Which row the pointer is over (drives the highlight);
                     * -1 when not over any row.
                     */
                    property int hoverIndex: -1

                    onVisibleChanged: {
                        root.previewOpen = preview.visible;
                    }

                    /** Window list pane, floating `gap` above the dock bar. */
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: preview.gap
                        radius: 12 * s
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.dockPaneTop }
                            GradientStop { position: 1.0; color: root.dockPaneBot }
                        }
                        border.width: 1
                        border.color: root.dockBorder
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.dockDim
                            shadowBlur: 1.0
                            shadowVerticalOffset: 6 * root.s
                        }

                        /** Glass top sheen, matching the dock slab. */
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.4
                            radius: parent.radius - 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.dockSheen }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    /**
                     * Hover keeper + click target in one: sits on top of the
                     * rows so the panel stays open wherever the pointer rests
                     * on it, and resolves which row was clicked from mouseY.
                     * (Rows used to own their own MouseAreas, which stole the
                     * hover from the keeper and closed the panel mid-walk-up.)
                     */
                    MouseArea {
                        id: panel
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function rowIndex(y) {
                            var i = Math.floor((y - preview.padT) / preview.rowH);
                            if (i < 0 || i >= preview.winCount) return -1;
                            return i;
                        }

                        onPositionChanged: {
                            preview.hoverIndex = rowIndex(mouseY);
                        }
                        onExited: {
                            preview.hoverIndex = -1;
                        }
                        onClicked: {
                            var i = rowIndex(mouseY);
                            if (i < 0) return;
                            var win = preview.wins[i];
                            root.previewOpen = false;
                            root.focusAddress(win.address);
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: preview.padT
                        anchors.bottomMargin: preview.padT + preview.gap
                        spacing: 0

                        Repeater {
                            model: preview.wins.length > 5 ? preview.wins.slice(0, 5) : preview.wins

                            delegate: Item {
                                required property var modelData
                                required property int index
                                readonly property bool activeRow: modelData.activated
                                width: preview.width
                                height: preview.rowH

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6 * s
                                    anchors.rightMargin: 6 * s
                                    radius: 9 * s
                                    color: root.dockHighlight
                                    opacity: (preview.hoverIndex === index) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9 * s
                                    anchors.right: metaRow.left
                                    anchors.rightMargin: 6 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: 11 * s
                                    color: root.dockCopy
                                    text: modelData.title ? modelData.title : "(untitled)"
                                }

                                Row {
                                    id: metaRow
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5 * s

                                    Text {
                                        font.pixelSize: 9 * s
                                        color: root.dockFaint
                                        verticalAlignment: Text.AlignVCenter
                                        text: modelData.workspace && modelData.workspace.name
                                            ? String(modelData.workspace.name) : ""
                                    }

                                    Rectangle {
                                        visible: activeRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 5 * s
                                        height: 5 * s
                                        radius: width / 2
                                        color: root.dockActive
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // First-run hint: nothing pinned and nothing running.
        Item {
            visible: root.items.length === 0
            width: root.chipW
            height: root.dockH

            readonly property bool hover: hintArea.containsMouse

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12 * s
                width: 32 * s
                height: 32 * s
                sourceSize.width: Math.round(64 * s)
                sourceSize.height: Math.round(64 * s)
                asynchronous: true
                smooth: true
                transformOrigin: Item.Bottom
                source: Quickshell.hasThemeIcon("starred") ? Quickshell.iconPath("starred", "application-x-executable") : ""
                opacity: parent.hover ? 0.8 : 0.55
                scale: parent.hover ? 1.32 : 1
                Behavior on scale { NumberAnimation { duration: Motion.fast } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: hintArea
                anchors.fill: parent
                hoverEnabled: true
            }

            Tooltip {
                show: parent.hover
                s: root.s
                placement: "above"
                title: "Right-click any app in the launcher to pin it here"
            }
        }
    }
}