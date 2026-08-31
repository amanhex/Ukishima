//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
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
     */
    function toggleSurface(mon, surface) {
        if (!mon || mon.length === 0)
            mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
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
            readonly property real restHeight: 38 * s

            /** Trimming the reserved band below the pill's bottom lets windows climb, so App gap sets the pill-to-window air without touching the desktop gaps_out. */
            readonly property real reservedH: Math.max(0, restHeight + topGap - 12 * (1 - Flags.appGap) * s)

            readonly property real gameBarH: 34 * s

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: Flags.gameMode ? gameBarH : (Flags.autoHide ? 0 : reservedH)
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: Flags.gameMode ? gameBarH : (Flags.autoHide ? 0 : reservedH)

            mask: emptyReserve
            Region { id: emptyReserve }
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
            readonly property bool modal: surfaceOpen || pill.held || pill.quickChoosing

            /**
             * True while this monitor's active workspace reports a fullscreen
             * client. The pill then retracts off the top edge and the whole
             * layer becomes click-through so fullscreen content owns the screen.
             */
            readonly property bool monFullscreen: {
                var mons = Hyprland.monitors.values;
                for (var i = 0; i < mons.length; i++) {
                    if (mons[i].name === modelData.name) {
                        var ws = mons[i].activeWorkspace;
                        var o = ws ? ws.lastIpcObject : null;
                        return o ? !!o.hasfullscreen : false;
                    }
                }
                return false;
            }

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                pill.pinned = false;
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
}
