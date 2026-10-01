//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
import "components"
import "surfaces"

/**
 * Ukishima top shell. Each monitor carries two layer-shell windows:
 *
 *  - `reserve` is a zero-content strip that only claims an exclusive zone the
 *    height of the rest pill, so tiled windows always sit below the pill even
 *    while it is expanded or a surface is open.
 *  - `overlay` is a full-screen transparent Overlay layer hosting the single
 *    morphing pill anchored at top-centre. The pill never moves windows and is
 *    never re-parented; it just grows in place, so every surface grows out of
 *    the rest pill instead of popping up as a separate panel.
 *
 * Input is routed by the window mask. While the pill is collapsed the mask is
 * the pill rect only, so the rest of the screen clicks through to windows.
 * While the pill is expanded (hovered/pinned) or a surface is open the mask is
 * cleared so the whole layer catches clicks. A backdrop press dismisses, and
 * keyboard focus is taken on demand so Escape closes the open surface.
 */
ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    /**
     * Last monitor Hyprland reported as focused, so a surface opened with an
     * empty monitor argument still lands on a real monitor while
     * `Hyprland.focusedMonitor` is still null. See toggleSurface.
     */
    property string lastFocusedMon: ""
    property string peekMon: ""

    /**
     * Battery notification latches, change-triggered by UPower (never polled).
     * Low battery escalates down the levels — 25% then 20% fire once each as a
     * normal warning, and 15% opens a critical announcement that repeats every
     * ten minutes until the battery is plugged in. The latch re-arms when the
     * battery charges or rises back above 25%. Full fires once when the battery
     * reports fully charged, so charge-limited systems (e.g. an 80% cut-off)
     * announce at their actual full point.
     */
    property int battNotifiedBelow: 100
    property bool fullBattNotified: false

    function battNote(urgency, summary, body) {
        battNoteProc.command = urgency.length > 0
            ? ["notify-send", "-a", "Ukishima", "-u", urgency, summary, body]
            : ["notify-send", "-a", "Ukishima", summary, body];
        battNoteProc.running = true;
    }

    /**
     * One-shot level crossings on the way down, lowest threshold first, so a
     * battery already below several levels (e.g. booting at 18%) only announces
     * the most urgent one it has passed — 20% there, never 25% and 20% together.
     * At or below the critical level the repeat timer takes over.
     */
    function battCheck() {
        if (!Battery.present)
            return;
        if (!Battery.discharging || Battery.pct > 25) {
            root.battNotifiedBelow = 100;
            if (root.battRepeatTimer)
                root.battRepeatTimer.stop();
            return;
        }
        var levels = [[15, "critical"], [20, "normal"], [25, "normal"]];
        for (var i = 0; i < levels.length; i++) {
            if (Battery.pct <= levels[i][0] && levels[i][0] < root.battNotifiedBelow) {
                root.battNotifiedBelow = levels[i][0];
                var critical = levels[i][1] === "critical";
                root.battNote(critical ? "critical" : "normal",
                    critical ? "Battery critical" : "Low battery",
                    Battery.pct + "% remaining — plug in your charger"
                    + (critical ? " now." : " soon."));
                break;
            }
        }
        if (Battery.pct <= 15 && root.battRepeatTimer && !root.battRepeatTimer.running)
            root.battRepeatTimer.start();
    }

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
        void GameMode.active;
        root.battCheck();
        wallpaperBootProc.running = true;
    }

    /**
     * Boot wallpaper restore. Hyprland starts awww-daemon at login, but a daemon
     * that has just come up has no image set, so the desktop came back black
     * after every reboot even though the state file and the per-output map were
     * written correctly the whole time — nothing ever read them back at startup.
     * This fires from the shell root rather than from the Walls singleton on
     * purpose: a `pragma Singleton` is only constructed the first time something
     * references it, and the only referencers are the wallpaper strip, the theme
     * settings page and the lock surface, all of which are loaded on demand. In
     * the singleton that hook would not run until the strip was first opened,
     * which is exactly the thing being fixed.
     *
     * wallpaper.sh init re-applies the recorded wallpaper only when the daemon is
     * painting nothing, so a plain shell restart against a correct desktop stays
     * silent instead of replaying the transition over it.
     */
    Process {
        id: wallpaperBootProc
        command: ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "init"]
    }

    Process {
        id: battNoteProc
    }

    Timer {
        id: battRepeatTimer
        interval: 10 * 60 * 1000
        repeat: true
        onTriggered: {
            if (!Battery.present || !Battery.discharging || Battery.pct > 15) {
                stop();
                return;
            }
            root.battNote("critical", "Battery critical",
                Battery.pct + "% remaining — plug in your charger now.");
        }
    }

    Connections {
        target: Battery
        function onPctChanged() { root.battCheck(); }
        function onDischargingChanged() { root.battCheck(); }
        function onFullChanged() {
            if (!Battery.present)
                return;
            if (Battery.full && !root.fullBattNotified) {
                root.fullBattNotified = true;
                root.battNote("normal", "Battery full",
                    Battery.pct + "% — you can unplug.");
            } else if (!Battery.full) {
                root.fullBattNotified = false;
            }
        }
    }

    /**
     * After an update relaunches the shell, raise a one-shot toast naming what
     * landed, so the apply ends in a confirmation instead of a silent restart. The
     * updater drops the marker just before it restarts; the short delay lets the
     * notification server own the bus before we post to it, and the marker is
     * removed as it is read so the toast only ever fires once.
     */
    Timer {
        interval: 2500
        running: true
        onTriggered: updatedToast.running = true
    }
    Process {
        id: updatedToast
        command: ["sh", "-c",
            "m=\"${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/updated\"; [ -f \"$m\" ] || exit 0; "
            + "b=$(cat \"$m\"); rm -f \"$m\"; "
            + "gdbus call --session --dest org.freedesktop.Notifications "
            + "--object-path /org/freedesktop/Notifications "
            + "--method org.freedesktop.Notifications.Notify "
            + "Pill 0 '' 'Pill updated' \"$b\" '[]' '{}' 5000 >/dev/null 2>&1"]
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ukishima-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    /**
     * The Wayland IdleInhibitor above only pauses the compositor's own idle
     * (DPMS); hypridle runs its own timer and never sees it, so the lock still
     * fired with keep-awake on. A logind idle inhibitor is the wire hypridle
     * does respect, so hold one for as long as the flag is set.
     */
    Process {
        running: Flags.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Ukishima",
                  "--why=keep awake", "--mode=block", "sleep", "infinity"]
    }

    /**
     * Only these raw events can change what the pill renders (per-monitor
     * active workspace, minimized toplevels, monitor hotplug). Everything
     * else (window drags, resizes, title spam) must not trigger the triple
     * model refresh, which costs three Hyprland IPC round-trips.
     */
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    /**
     * An empty monitor argument resolves to the focused monitor here, so the
     * keybind scripts skip their hyprctl+jq round trip and a surface open costs
     * one IPC call instead of three process spawns.
     *
     * The fallback chain exists because `Hyprland.focusedMonitor` is null on a
     * fresh launch — the same null the workspace dots work around
     * (Workspaces.qml's header). Left as `""`, `openMon` matched no pill: each
     * pill takes its surface from `root.openMon === modelData.name ? … : ""`
     * (shell.qml:472), so the surface was set, no pill displayed it, and a
     * second identical call matched `openMon === ""` and closed it again. The
     * net effect was that every bare keybind — the documented form, passing `""`
     * — silently did nothing until something else had populated the Hyprland
     * models, while `ipc call … <monitor>` worked. Hence: last known focused
     * monitor, then the first screen.
     */
    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0) {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
                mon = Hyprland.focusedMonitor.name;
            else if (root.lastFocusedMon.length > 0)
                mon = root.lastFocusedMon;
            else if (Quickshell.screens.length > 0)
                mon = Quickshell.screens[0].name;
        }
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    /**
     * True while the named monitor's active workspace reports a fullscreen
     * client. One definition, because the pill's band and the dock's band both
     * have to agree with their own bar about when that bar is on screen: the
     * pill and the dock each retract off their edge, and a band kept reserved
     * for a bar that has gone is a hole in the desktop.
     */
    function fullscreenOn(name) {
        if (!name)
            return false;
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++) {
            if (mons[i].name === name) {
                var ws = mons[i].activeWorkspace;
                var o = ws ? ws.lastIpcObject : null;
                return o ? !!o.hasfullscreen : false;
            }
        }
        return false;
    }

    /**
     * Whether the dock bar is on screen on this monitor: enabled, and not
     * retracted by a fullscreen client or by game mode. The bar window and the
     * band that reserves its space both read this, so the two can never disagree
     * about whether the dock is showing -- which is what left a reserved hole in
     * the desktop whenever the dock hid while the band did not.
     */
    function dockBarShown(mon) {
        return Flags.dockEnabled && !root.fullscreenOn(mon) && !Flags.gameMode;
    }

    /**
     * Remember the focused monitor for toggleSurface's fallback. Cheap: it only
     * writes when the name actually changes.
     */
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== root.lastFocusedMon)
                root.lastFocusedMon = Hyprland.focusedMonitor.name;
        }
    }

    IpcHandler {
        target: "ukishima"
        function mixer(mon: string): void { root.toggleSurface(mon, "mixer"); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function power(mon: string): void { root.toggleSurface(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function recorder(mon: string): void { root.toggleSurface(mon, "recorder"); }
        function screenrec(mon: string): void { root.toggleSurface(mon, "recorder"); }
        function record(mon: string): void { root.toggleSurface(mon, "recorder"); }

        /**
         * Quick-record keybind (SUPER+D): one button cycles the whole flow with no
         * surface. Recording → stop. Counting down → cancel. A chooser already up
         * on this monitor → dismiss. Otherwise open the standalone source chooser on
         * the focused monitor `mon`, so only that pill renders it.
         */
        function quickRecord(mon: string): void {
            if (ScreenRec.recording) {
                ScreenRec.stop();
            } else if (ScreenRec.counting) {
                ScreenRec.cancel();
            } else if (ScreenRec.quickChoosing) {
                ScreenRec.quickChoosing = false;
                ScreenRec.quickScreenChoosing = false;
            } else {
                ScreenRec.quickMon = mon;
                ScreenRec.quickScreenChoosing = false;
                ScreenRec.quickChoosing = true;
            }
        }
        function gameMode(mon: string): void { Flags.gameMode = !Flags.gameMode; }
        function sysmon(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function system(mon: string): void { root.toggleSurface(mon, "sysmon"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
        function media(mon: string): void {
            if (Players.list.length > 0)
                root.toggleSurface(mon, "media");
        }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.close(); }

        /**
         * Memory saver door: drop every closed surface on every monitor right
         * away, regardless of how much of its 30s tail is left. The open
         * surface is never touched; reopening a dropped surface rebuilds it.
         */
        function unloadAll(): void { Surfaces.unloadClosed(); }

        /** Opens any surface by name, settings sub-pages included; dev and scripting door. */
        function page(mon: string, name: string): void { root.toggleSurface(mon, name); }

        /**
         * The two halves of the SUPER+M minimize toggle, driven by the
         * minimize-toggle script which has already read the focused window. A
         * desktop window drops into the minimized stash; a window already stashed
         * comes back to the workspace it is handed, so the same key hides and
         * restores. Both target the window by address so they act on the one the
         * user pressed on, not whatever the compositor calls active afterwards.
         */
        function minimizeWindow(addr: string): void {
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + addr + '" })');
        }
        function restoreWindow(arg: string): void {
            var p = arg.split("|");
            if (p.length < 2 || p[0].length === 0)
                return;
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + p[1] + '", window = "address:' + p[0] + '" })');
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            /**
             * Reserved-band ceiling with auto-hide off. A full-footprint reserve
             * (hover 58, quick-record 76) cost too much window space, so this is
             * just the resting face plus the transient OSD ring (44): the flashes
             * that actually cover windows (workspace/volume/brightness/record)
             * stay clear, while the cursor-driven hover (58) may still dip past
             * the band by a few pixels.
             */
            readonly property real restFaceH: 44 * s

                        /** Trimming the reserved band below the pill's bottom lets windows climb, so App gap sets the pill-to-window air without touching the desktop gaps_out. The strip face docks flush to the screen top (its own topGap is zero), so it never adds the margin. */
            readonly property real reservedH: Flags.mainDisplay === "strip"
                ? Math.max(0, restFaceH - 12 * (1 - Flags.appGap) * s)
                : Math.max(0, restFaceH + topGap - 12 * (1 - Flags.appGap) * s)

            readonly property real gameBarH: 34 * s

            /**
             * The band is reserved only while the pill is on screen. Game mode
             * keeps the pill up as a slim bar, so it keeps a slim band; a
             * fullscreen client slides the pill clean off the top edge, and that
             * case used to fall through to reservedH and leave a hole in the
             * desktop with nothing in it, the same defect the dock's band had.
             * The condition is named once because it drove both exclusiveZone and
             * implicitHeight, which must agree.
             */
            readonly property bool monFullscreen: root.fullscreenOn(modelData.name)
            readonly property real bandH: monFullscreen ? 0 : (Flags.gameMode ? gameBarH : (Flags.autoHide ? 0 : reservedH))

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: bandH
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: bandH

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockReserve
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            /**
             * Bottom band the dock sits in: just the bar's footprint plus its
             * float gap, so tiled windows climb above the resting dock but the
             * strips on either side stay usable. With dock auto-hide on nothing
             * is reserved at all and the dock floats over the desktop until the
             * edge is touched; while the dock is retracted empty (no pins, no
             * running apps, no usage-history shelf — DockState.empty) the band
             * is released too, so windows may tile all the way down. Kept in
             * step with DockBar.dockH (components/DockBar.qml): minimal chips
             * are shorter than titled ones, and the float lip mirrors the
             * pill's topGap at half scale.
             */
            readonly property real dockH: (Flags.dockMinimal ? 58 : 68) * s
            readonly property real dockGap: 4 * Flags.topGap * s
            readonly property real reservedH: dockH + dockGap

            /** Whether the dock bar is actually on screen here; mirrors dockWin.suppressed. */
            readonly property bool barShown: root.dockBarShown(modelData.name)

            /**
             * The band is reserved only while the bar that fills it is on screen.
             * This used to key off dockEnabled and auto-hide alone, so the space
             * survived every state that hides the dock: game mode and a
             * fullscreen client both retract the bar, and the band stayed, a hole
             * in the desktop with nothing in it. Keyed to barShown, the same
             * predicate dockWin uses to decide suppression, so the two cannot
             * disagree. A once-duplicated condition, now named once.
             */
            readonly property real bandH: (barShown && !Flags.dockAutoHide && !DockState.empty) ? reservedH : 0

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: bandH
            aboveWindows: true

            anchors { bottom: true; left: true; right: true }
            implicitHeight: bandH

            mask: emptyDockReserve
            Region { id: emptyDockReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            readonly property real topGap: 8 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: surfaceOpen || pill.held || pill.quickChoosing || pill.expandLatch

            /**
             * True while this monitor's active workspace reports a fullscreen
             * client. The pill then retracts off the top edge and the whole
             * layer becomes click-through so fullscreen content owns the screen.
             */
            readonly property bool monFullscreen: root.fullscreenOn(modelData.name)

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                pill.pinned = false;
                pill.expandLatch = false;
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: ((surfaceOpen || pill.quickChoosing)) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "ukishima"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: monFullscreen ? hiddenRegion : (modal ? fullRegion : (pill.mode === "game" ? pillRegion : (Flags.autoHide ? (pill.revealSession || pill.transientLive ? revealPillRegion : (pill.expanded ? pillRegion : revealRegion)) : pillRegion)))
            Region { id: hiddenRegion }

            /**
             * The only input left alive while the pill is auto-hidden: a thin
             * top-centre edge strip the pointer can always find. Hovering it
             * slides the pill back in, whether it is resting on a focused
             * monitor or retracted off a non-focused one. Kept to a few pixels
             * so the pill only ever appears when the cursor actually touches the
             * screen edge — passing through the top area deeper down triggers
             * nothing, and (because the strip doubles as the reveal input mask)
             * no invisible click-blocking band lingers below the visible pill.
             */
            Region {
                id: revealRegion
                readonly property real revealW: pill.stripBar ? Math.max(420 * pill.s, pill.stripFaceW) : 420 * pill.s
                readonly property real revealH: 10 * pill.s
                x: Math.max(0, overlay.width / 2 - revealW / 2)
                y: 0
                width: revealW
                height: revealH
            }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: pill.x + (pill.width - baseW) / 2
                y: pill.y
                width: baseW + pill.inputPadRight
                height: Math.max(pill.height, pill.targetH)
            }

            /**
             * Mask while the pill is being pulled in from the reveal strip. The
             * plain pillRegion alone would flicker: it follows the pill's morphing
             * geometry, so a cursor waiting in the strip below the still-growing
             * pill slips out of the mask, drops the hover, and re-triggers the
             * reveal in a loop. Unioning the fixed strip keeps the cursor covered
             * for the whole pull-in; the pill part grows to catch it on the way up.
             */
            Region {
                id: revealPillRegion
                x: revealRegion.x
                y: revealRegion.y
                width: revealRegion.width
                height: revealRegion.height

                Region {
                    x: pillRegion.x
                    y: pillRegion.y
                    width: pillRegion.width
                    height: pillRegion.height
                }
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else if (overlay.surfaceOpen) {
                        var inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside)
                            root.close();
                        else if (mouse.y <= pillRegion.y + 40 * pill.s)
                            pill.surfaceBack();
                    } else {
                        pill.pinned = false;
                        pill.expandLatch = false;
                        root.peekMon = "";
                    }
                }
            }

            Connections {
                target: Flags
                function onAutoHideChanged() {
                    if (!Flags.autoHide) {
                        pill.revealSession = false;
                        pill.hovered = false;
                        pill.hoverLatch = false;
                    } else {
                        pill.pinned = false;
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.surfaceOpen || pill.quickChoosing

                HoverHandler {
                    enabled: !overlay.surfaceOpen && !pill.pinned
                    onHoveredChanged: if (enabled) pill.hovered = hovered
                }
                Keys.onEscapePressed: {
                    if (pill.wallpaperMenuOpen) {
                        pill.wallpaperMenuClose();
                    } else if (pill.quickChoosing) {
                        ScreenRec.quickChoosing = false;
                        ScreenRec.quickScreenChoosing = false;
                    } else {
                        root.close();
                    }
                }
                Keys.onUpPressed: (e) => {
                    if (pill.wallpaperMenuOpen) { pill.wallpaperMenuMove(-1); e.accepted = true; }
                    else e.accepted = pill.mixerStep(1) || pill.recorderStep(5) || pill.settingsMove(-1);
                }
                Keys.onDownPressed: (e) => {
                    if (pill.wallpaperMenuOpen) { pill.wallpaperMenuMove(1); e.accepted = true; }
                    else e.accepted = pill.mixerStep(-1) || pill.recorderStep(-5) || pill.settingsMove(1);
                }
                Keys.onLeftPressed: (e) => {
                    if (pill.wallpaperMenuOpen) { e.accepted = true; }
                    else if (pill.mixerOpen) { pill.mixerFocusMove(-1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(-1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(-5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(-1); e.accepted = true; }
                }
                Keys.onRightPressed: (e) => {
                    if (pill.wallpaperMenuOpen) { e.accepted = true; }
                    else if (pill.mixerOpen) { pill.mixerFocusMove(1); e.accepted = true; }
                    else if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; }
                    else if (pill.powerOpen) { pill.powerMove(1); e.accepted = true; }
                    else if (pill.recorderOpen) { e.accepted = pill.recorderStep(5); }
                    else if (pill.settingsLike) { pill.settingsAdjust(1); e.accepted = true; }
                }

                /**
                 * Return/Enter/Space: the wallpaper strip applies its focused
                 * thumb on every press; the power surface fires a safe tile on
                 * the first press and, for a destructive tile, holds the heat
                 * fill across autorepeat presses (drained on release). Autorepeat
                 * is swallowed for everything else so a held key never re-fires.
                 */
                Keys.onPressed: (e) => {
                    if (pill.wallpaperMenuOpen) {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                            if (!e.isAutoRepeat) pill.wallpaperMenuPick();
                            e.accepted = true;
                        } else if (e.text.length === 1) {
                            e.accepted = true;
                        }
                        return;
                    }
                    if (pill.wallpaperWh && !pill.wallpaperWhTyping) {
                        if (e.key === Qt.Key_Backspace) {
                            pill.wallpaperWhBackspace();
                            e.accepted = true;
                            return;
                        }
                        if (e.text.length === 1 && e.text > " ") {
                            pill.wallpaperWhType(e.text);
                            e.accepted = true;
                            return;
                        }
                    }
                    if (pill.wallpaperOpen && !pill.wallpaperSearching && !pill.wallpaperWh
                        && e.text.length === 1 && e.text > " ") {
                        pill.wallpaperType(e.text);
                        e.accepted = true;
                        return;
                    }
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space)
                        return;
                    if (pill.wallpaperOpen) {
                        if (!e.isAutoRepeat) pill.wallpaperActivate();
                        e.accepted = true;
                    } else if (pill.powerOpen) {
                        if (!e.isAutoRepeat) pill.powerPress();
                        e.accepted = true;
                    } else if (pill.settingsLike) {
                        if (!e.isAutoRepeat) pill.settingsActivate();
                        e.accepted = true;
                    }
                }
                Keys.onReleased: (e) => {
                    if (e.isAutoRepeat)
                        return;
                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                        && pill.powerOpen) {
                        pill.powerRelease();
                        e.accepted = true;
                    }
                }

                /**
                 * Drag-and-drop gateway for the auto-hidden pill. The reveal
                 * strip keeps its input while the pill is retracted, but drops
                 * are routed to drop targets, not to the passive HoverHandler
                 * that opens the strip — so a hidden pill would never see a
                 * dragged file. This target shadows the strip's geometry, pulls
                 * the pill in on drag enter and hands the drop to the same
                 * install flow as the resting pill. Sits below the pill in the
                 * scene so drops on the visible pill itself keep winning.
                 */
                DropArea {
                    id: stripDrop
                    width: pill.stripBar ? Math.max(420 * overlay.s, pill.width) : 420 * overlay.s
                    height: 8 * overlay.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    enabled: Flags.autoHide && !pill.surfaceOpen && !pill.quickChoosing
                        && !pill.quickCounting && !Flags.gameMode
                    visible: enabled
                    keys: ["text/uri-list"]
                    onEntered: (drag) => {
                        drag.acceptProposedAction();
                        pill.revealSession = true;
                        pill.dropEntered(drag.urls);
                    }
                    onExited: {
                        pill.dropExited();
                        pill.revealSession = false;
                    }
                    onDropped: (drop) => {
                        drop.acceptProposedAction();
                        pill.dropDropped(drop.urls);
                        pill.revealSession = false;
                    }
                }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: (pill.stripBar || pill.mode === "game") ? 0 : overlay.topGap
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on anchors.topMargin {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    s: overlay.s
                    screenName: overlay.modelData.name
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: root.peekMon === overlay.modelData.name

                    opacity: (overlay.monFullscreen && !pill.transientLive) ? 0 : (osdPopup.active ? 0 : 1)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    transform: Translate {
                        y: ((overlay.monFullscreen && !pill.transientLive) || pill.hidden) ? -(pill.height + overlay.topGap) : 0
                        Behavior on y {
                            NumberAnimation {
                                duration: Motion.morph
                                easing.type: Motion.easeMorph
                                easing.bezierCurve: Motion.morphCurve
                            }
                        }
                    }

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.close()
                }

                OsdPopup {
                    id: osdPopup
                    anchors.top: parent.top
                    anchors.topMargin: (pill.stripBar || pill.mode === "game") ? 0 : overlay.topGap
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    expanded: pill.expanded
                    topFlat: (pill.mode === "game" || pill.stripBar) ? 1 : 0
                    suppressed: overlay.surfaceOpen || pill.held || pill.quickChoosing
                        || pill.quickCounting || pill.mode === "game" || (pill.toastActive && Notifs.toastCritical)
                }
            }

            onSurfaceOpenChanged: if (surfaceOpen) focusScope.forceActiveFocus()

            Connections {
                target: pill
                function onQuickChoosingChanged() {
                    if (pill.quickChoosing)
                        focusScope.forceActiveFocus();
                }
                function onWallpaperSearchingChanged() {
                    if (!pill.wallpaperSearching && overlay.surfaceOpen)
                        focusScope.forceActiveFocus();
                }
            }
        }
    }

    /**
     * Per-monitor dock, mirroring the pill's two-window split: `dockReserve`
     * claims the bottom band as an exclusive zone while the dock is persistent
     * (enabled and not auto-hiding), and this full-screen overlay hosts the
     * `DockBar` pinned to the bottom edge. Its mask is the bar rect while the
     * dock is shown; with auto-hide on, a thin bottom-centre strip stays live
     * so the pointer can always pull the bar back in, and the whole layer goes
     * click-through while the monitor runs fullscreen or game mode is active
     * (surfaces do not suppress it: opening the launcher or a settings page
     * keeps the dock on screen and usable). Keyboard focus is never taken, so
     * the dock can not steal focus from a tiled window below.
     */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWin
            required property var modelData
            readonly property real s: modelData ? (modelData.height / 1080) * Flags.uiScale : 1
            /** Float gap between the resting dock and the screen's bottom edge: a subtle lip, smaller than the pill's topGap float. */
            readonly property real dockGap: 4 * Flags.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0

            /**
             * The dock is off screen here, and retracts off the bottom edge: it
             * is switched off, or a fullscreen client owns the screen, or game
             * mode has quieted the desktop. Read from the same predicate the
             * band that reserves this bar's space uses, so the bar and the space
             * it occupies can never come apart.
             */
            readonly property bool suppressed: !root.dockBarShown(modelData.name)

            /**
             * The one state where suppression must NOT take the panel with it.
             *
             * The dock's settings panel carries its own "Dock" switch, and that
             * switch turns off the very bar whose gear opened the panel. Hosting
             * the panel here, as a sibling of the bar rather than a child of it,
             * is what makes that survivable: the panel stays put while the bar
             * goes, so the panel is still a way back for the few seconds it takes
             * to change your mind.
             *
             * The pill's Display surface also carries a "Dock" switch
             * (`dockRow` there), which is the real way back and needs none of
             * this. This is the belt to that pair of braces, so switching the
             * dock off from the dock's own settings never becomes a one-way door
             * — and it is scoped narrowly, so fullscreen and game mode still
             * hide everything and nothing else can pin a panel to the screen.
             */
            readonly property bool dockForcedOpen: dock.settingsOpen && !Flags.dockEnabled

            /**
             * The block the panel and the bar occupy together, and the whole of
             * the input region while the panel is open. Dismissal is NOT decided
             * here: it rides the bar's existing "the pointer has left" signal —
             * the same `hovered` flag and the same 350ms grace that drive the
             * dock's own auto-hide — so the panel and the bar cannot disagree
             * about when the pointer went away. See `revealTimer` in DockBar.
             *
             * This is not the arrangement that was here first, and the reason is
             * worth keeping because the wrong version looked defensible. It
             * asked the panel for a `pointerInside` flag and treated that as a
             * VETO on dismissing, which made it unreliable: the panel is opened
             * from the gear, which sits on the bar, so on the ordinary path the
             * pointer never crosses the panel and the veto is never satisfied.
             * It fired only when the pointer happened to travel through the
             * panel on its way somewhere else — which is the "sometimes" exactly.
             *
             * The part of that diagnosis that was wrong, and that a sentinel
             * outline was built on: leave events are not the problem. A
             * per-item hover flag does go stale, because leaving is the absence
             * of an event rather than an event, so a flag can only ever say "I
             * think it left" and never "it left". But the same signal drives the
             * bar's auto-hide, which demonstrably works, so the honest reading
             * is that stale flags were never what made this intermittent. The
             * fix is to decide from the one flag the bar already acts on, not to
             * stand a second mechanism up beside it.
             *
             * The region is the block itself, with no margin grown around it.
             * Extra margin buys a hover-based dismissal nothing — the pointer
             * only has to leave the block to be gone — and it is not free: every
             * pixel of margin is screen this window takes from whatever is
             * underneath. A bounding box is not a union, though, so the block
             * does carry dead space beside the panel and in the gap above the
             * bar, and the click floor below is what answers for that.
             */
            readonly property rect dismissBase: dockForcedOpen
                ? Qt.rect(dockPanelRegion.x, dockPanelRegion.y, dockPanelRegion.width, dockPanelRegion.height)
                : Qt.rect(dockSettingsUnion.x, dockSettingsUnion.y, dockSettingsUnion.width, dockSettingsUnion.height)

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "ukishima-dock"

            anchors { top: true; left: true; right: true; bottom: true }

            /**
             * The dock's settings panel floats above the bar, so it needs its own
             * region or it draws without taking clicks. Unioned with the bar
             * itself: the gear that opened it stays clickable to close it, and the
             * chips stay live underneath.
             */
            Region {
                id: dockSettingsUnion
                readonly property real l: Math.min(dockRegion.x, dockPanelRegion.x)
                readonly property real t: Math.min(dockRegion.y, dockPanelRegion.y)
                x: l
                y: t
                width: Math.max(dockRegion.x + dockRegion.width, dockPanelRegion.x + dockPanelRegion.width) - l
                height: Math.max(dockRegion.y + dockRegion.height, dockPanelRegion.y + dockPanelRegion.height) - t
            }

            Region {
                id: dockPanelRegion
                x: dockPanel.x
                y: dockPanel.y
                width: dockPanel.width
                height: dockPanel.height
            }

            /**
             * The panel is a sibling of the bar, not a child, so it is NOT
             * translated when the bar slides away. That is deliberate and is what
             * `dockForcedOpen` above exists for: switching the dock off from
             * inside its own settings must not strand the user.
             *
             * While the panel is open the region is `dismissBase`: the panel and
             * the bar as one rect. It is a single rect rather than the two it
             * stands in for, because a bounding box is what `hovered` needs to
             * agree with — the pointer can cross the gap between the panel and the
             * bar on its way from one to the other without that reading as a
             * departure, which is what you want. The cost is dead space beside
             * the panel, and that is what the click floor exists to cover: it is
             * exactly the space where a click would be delivered to this window
             * and hit nothing at all.
             *
             * The rest of the mask, and what each state needs to keep reachable:
             *
             *  - Suppressed or empty: nothing, so the screen is entirely free.
             *  - Auto-hide on: the reveal strip alone while retracted, so the
             *    pointer can always find the bar again; the strip unioned with
             *    the pop band once it is up, so the pull-in cannot flicker.
             *  - Auto-hide off: the bar can never retract, so no reveal strip is
             *    needed at any point. Naming the pop band alone covers the bar
             *    plus the space above it — it already contains the bar, whose
             *    width it spans and whose bottom edge it stops at.
             */
            mask: dock.settingsOpen
                ? dockDismissRegion
                : (suppressed || dock.empty ? dockHiddenRegion
                    : (Flags.dockAutoHide ? ((dock.revealSession || dock.hovered) ? dockRevealUnion : dockRevealRegion)
                        : (dock.hovered || dock.previewOpen ? dockPopBand : dockRegion)))
            Region { id: dockHiddenRegion }

            /**
             * The region behind the panel: the block, and nothing grown around it.
             * It is the same rect `dismissBase` describes, and it is the whole of
             * what `hovered` is measured against while the panel is open.
             */
            Region {
                id: dockDismissRegion
                x: dockWin.dismissBase.x
                y: dockWin.dismissBase.y
                width: dockWin.dismissBase.width
                height: dockWin.dismissBase.height
            }

            /**
             * A thin bottom-centre strip kept in the input mask while the dock
             * is retracted, so the pointer can always find it; hovering slides
             * the bar back up. Mirrors the pill's top reveal strip.
             */
            Region {
                id: dockRevealRegion
                readonly property real revealW: Math.max(420 * dock.s, dock.width)
                readonly property real revealH: 10 * dock.s
                x: Math.max(0, dockWin.width / 2 - revealW / 2)
                y: dockWin.height - revealH
                width: revealW
                height: revealH
            }

            /**
             * Mask while the bar is up: the dock's own footprint, so the rest
             * of the screen clicks through to windows.
             */
            Region {
                id: dockRegion
                x: dock.x
                y: dock.y
                width: dock.width
                height: dock.height
            }

            /**
             * The area above the bar that has to stay live while the bar is up.
             *
             * This is the distance the pointer must travel before the dock will
             * let go, so it is not decoration — it IS the hide threshold, and it
             * was set for the tallest thing that can float above the bar (a
             * window preview, ~190px) and then applied unconditionally. With
             * nothing floating, that meant 190px of screen stayed hot and the
             * dock hung around long after the pointer had clearly left it.
             *
             * So the band is sized to what is actually there:
             *
             *  - A preview is open: the full 190, and 100px past each end,
             *    because the cursor genuinely walks up into it and clicks a
             *    window row. That needs input, and the preview is wider than
             *    the bar.
             *  - Otherwise: just past the tallest chip tooltip (~44px, and
             *    non-interactive, so this is about the dock not blinking out
             *    from under a tooltip rather than about taking clicks). The
             *    side margin is near zero for the same reason — a tooltip is
             *    centred on a chip, so it can overhang the bar's end, but it
             *    never needs to be clicked.
             *
             * `previewOpen` rather than "is the pointer over a chip", because
             * the deep band exists for the preview's benefit alone; claiming it
             * while merely hovering a chip would reinstate the long threshold
             * for the most common interaction there is.
             */
            Region {
                id: dockPopBand
                readonly property bool deep: dock.previewOpen
                readonly property real bandH: (deep ? 190 : 44) * dock.s
                readonly property real sideW: (deep ? 100 : 6) * dock.s
                x: Math.max(0, dock.x - sideW)
                y: Math.max(0, dock.y - bandH)
                width: dock.width + sideW * 2
                height: bandH + dock.height
            }

            /**
             * Mask while the bar is up with auto-hide ON, which is the only case
             * that needs the reveal strip: the bar retracts, so the strip is what
             * keeps the pointer able to find and re-reveal it.
             *
             * The plain dockRegion alone would flicker: the strip is wider than
             * the empty bar, so a cursor resting on the strip's outer edge would
             * slip out of the mask mid-slide and re-trigger the reveal. Unioning
             * the fixed strip keeps the cursor covered for the whole pull-in.
             */
            Region {
                id: dockRevealUnion
                x: dockRevealRegion.x
                y: dockRevealRegion.y
                width: dockRevealRegion.width
                height: dockRevealRegion.height

                Region {
                    x: dockPopBand.x
                    y: dockPopBand.y
                    width: dockPopBand.width
                    height: dockPopBand.height
                }
            }

            DockBar {
                id: dock

                /**
                 * Above the settings panel, which sits at z 200.
                 *
                 * This inverts the popover relationship, and deliberately. The
                 * panel is anchored to the bar's TOP, so the two never overlap
                 * — nothing the bar paints in its own rectangle can cover the
                 * panel. What DOES overlap is what the bar floats UP out of
                 * itself: the chip tooltips and the multi-window preview, both
                 * anchored above their chip, which is to say inside the panel.
                 *
                 * As siblings those were unreachable whenever the panel was open:
                 * hovering a chip to read its name showed a tooltip painted
                 * behind an opaque panel, so it simply was not there. A z value
                 * is per-branch and there is no "escape to the window root", so
                 * the bar has to come above the panel as a whole to lift its own
                 * decorations with it.
                 *
                 * The tooltips are the reason this is right rather than merely
                 * convenient: the panel being open must not cost the user the
                 * names of the apps they are pointing at. Input is unaffected —
                 * a tooltip is non-interactive by design, so it never claims a
                 * click from a panel row underneath it.
                 */
                z: 250
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dockWin.dockGap
                s: dockWin.s
                suppressed: suppressed
                screenName: dockWin.modelData.name

                /**
                 * Slide the bar below the screen edge while the dock is
                 * retracted (monitor fullscreen, game mode, disabled, or
                 * auto-hidden after the pointer leaves) and while it has
                 * nothing to show — no pins, no running apps and no usage
                 * history for a frequent-app shelf (`empty`). The translate
                 * covers the bar plus its float gap, so nothing peeks back
                 * above the edge while hidden.
                 */
                transform: Translate {
                    y: dock.hidden || dock.empty || suppressed ? dock.height + dockWin.dockGap : 0
                    Behavior on y {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                }
            }

            /**
             * The dock's OWN settings panel, hosted here rather than inside
             * DockBar for one reason: it must survive the bar being translated
             * off the bottom edge, because the panel holds the "Dock" switch and
             * the bar holds the gear. Two things make that work.
             *
             * It is a SIBLING of the bar, and it anchors to the bar's layout
             * position — a Transform moves the painting, not `x`/`y`, so
             * anchoring here reads the untranslated position and the panel holds
             * still while the bar slides away.
             *
             * And the shell, not the dock, decides the panel's palette input and
             * its input-mask region, because the mask has to cover the panel
             * alone in `dockForcedOpen` — the bar is gone, so the union would be
             * wrong.
             *
             * Loaded, not instantiated, so the app list's desktop-entry scan is
             * not paid for while the panel is closed. Its size is left entirely
             * to the Loader's own implicit sizing, which follows the page's
             * `implicitWidth`/`implicitHeight`: binding `width` to `item.width`
             * looks equivalent and is not — the Loader resizes a loaded item to
             * its own width, so on the tick the item appears the width reads 0,
                 * the Loader resizes the page to 0, and the two pin each other at
             * zero. That is the panel's own input-mask region, so a silent zero
             * there is a panel that draws and takes no clicks.
             */
            Loader {
                id: dockPanel
                active: dock.settingsOpen
                visible: dock.settingsOpen
                z: 200
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dock.top
                /* A POSITIVE bottom margin lifts the panel clear of the bar, as
                 * it does for every other margin: the item's bottom sits that
                 * many pixels above the anchor line. */
                anchors.bottomMargin: dock.panelGap

                sourceComponent: Component {
                    DockSurface {
                        s: dock.s
                        pal: dock.dockPal
                        open: true
                        onRequestClose: dock.closeSettings()
                    }
                }
            }

            /**
             * The other half of click-away: a click that lands on THIS window but
             * on neither the panel nor the bar.
             *
             * The region while the panel is open is one rect that encloses both,
             * which leaves dead space beside the panel and in the gap between
             * panel and bar. A click in any of it is delivered to this window
             * and hits nothing, so it deserves a direct answer rather than
             * waiting on a hover that may not come. Note what this floor is
             * standing in for: the panel's own dismissal is the bar's
             * `revealTimer`, and the pointer has to LEAVE the block for that to
             * fire, which a click never does on its own. This is what answers
             * the click, so the two are not redundant.
             *
             * z is BELOW the bar (which is 0) and far below the panel (200), so
             * this never sees a click meant for a chip or a row — it is a floor,
             * not a lid.
             */
            MouseArea {
                z: -1
                anchors.fill: parent
                visible: dock.settingsOpen
                onClicked: dock.closeSettings()
            }

            /**
             * The one hover feed for the whole dock window, and with it the
             * panel's dismissal: while the panel is open the mask is the block,
             * so `hovered` reads as "over the panel or the bar" and the bar's
             * `revealTimer` closes the panel once the pointer has left.
             *
             * It stays enabled while `suppressed`, which looks wrong and is not.
             * `suppressed` covers the dock being switched off, and that is
             * reachable from inside the open panel — the panel is a sibling of
             * the bar precisely so it survives the bar sliding away. Pause the
             * feed there and the one case that most needs a dismissal signal
             * loses it, with the flag frozen at whatever it last read. DockBar
             * clears the flags on the way in, so nothing is left latched.
             */
            HoverHandler {
                enabled: !suppressed || dock.settingsOpen
                onHoveredChanged: if (enabled) dock.hovered = hovered
            }

            Connections {
                target: Flags
                function onDockAutoHideChanged() {
                    if (!Flags.dockAutoHide) {
                        dock.revealSession = false;
                        dock.hovered = false;
                    }
                }
                function onDockEnabledChanged() {
                    if (!Flags.dockEnabled) {
                        dock.revealSession = false;
                        dock.hovered = false;
                    }
                }
            }
        }
    }

    // The built-in polkit authentication agent. Mounting it here is the only
    // thing that instantiates it: a Quickshell config directory auto-loads
    // shell.qml and nothing else, so a sibling root file is never loaded on its
    // own and polkitd silently falls back to a textual agent without this.
    Polkit { }
}
