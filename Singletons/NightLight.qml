pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 灯 Night-light controller over hyprsunset, the Hyprland blue-light filter.
 * Off and On push straight to the running daemon over its IPC, so the screen
 * warms or clears at once with no service flicker. Scheduled mode writes a
 * two-profile hyprsunset.conf and restarts the service, handing the clock to the
 * daemon so the tint flips at the set times on its own and survives a logout.
 * The mode, warmth and the two times all live in Flags, so the pill and a fresh
 * login restore the same state. Turning it on confirms the binary and starts the
 * user service if it is not already up, so an install that skipped the service
 * still works.
 */
Singleton {
    id: root

    readonly property string confPath: Config.hyprPath("hyprsunset.conf")
    property bool available: false
    property string pendingMode: ""

    function clampTemp(t) {
        return Math.max(2200, Math.min(6000, Math.round(t)));
    }

    function nowMin() {
        var d = clock.date;
        return d.getHours() * 60 + d.getMinutes();
    }

    /** True while the clock sits inside the on→off window, with the wrap past midnight handled. */
    function windowOpen() {
        var on = Flags.nightLightOnMin;
        var off = Flags.nightLightOffMin;
        var n = root.nowMin();
        return on <= off ? (n >= on && n < off) : (n >= on || n < off);
    }

    function hhmm(min) {
        var h = Math.floor(min / 60);
        var m = min % 60;
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    /** hyprsunset.conf for the current Flags. Off and On are one all-day profile, Scheduled is two. */
    function buildConf() {
        var out = "max-gamma = 150\n\n";
        if (Flags.nightLightMode === "scheduled") {
            out += "profile {\n    time = " + root.hhmm(Flags.nightLightOnMin)
                + "\n    temperature = " + root.clampTemp(Flags.nightLightTemp) + "\n}\n\n"
                + "profile {\n    time = " + root.hhmm(Flags.nightLightOffMin)
                + "\n    identity = true\n}\n";
        } else if (Flags.nightLightMode === "on") {
            out += "profile {\n    time = 0:00\n    temperature = "
                + root.clampTemp(Flags.nightLightTemp) + "\n}\n";
        } else {
            out += "profile {\n    time = 0:00\n    identity = true\n}\n";
        }
        return out;
    }

    /** The IPC command the current mode and clock resolve to. */
    function desiredCmd() {
        var warm = Flags.nightLightMode === "on"
            || (Flags.nightLightMode === "scheduled" && root.windowOpen());
        return warm
            ? ["hyprctl", "hyprsunset", "temperature", String(root.clampTemp(Flags.nightLightTemp))]
            : ["hyprctl", "hyprsunset", "identity"];
    }

    /**
     * Pushes the resolved state to the live daemon at once. A scrub tick that
     * lands while the prior hyprctl is still running is folded into the trailing
     * re-push in the process exit handler, so the final value always arrives.
     */
    function pushLive() {
        if (ipc.running)
            return;
        if (!root.available) {
            ipc.command = root.desiredCmd();
            return;
        }
        ipc.command = root.desiredCmd();
        ipc.running = true;
    }

    property bool pendingRestart: false

    /**
     * Persists conf for the next login and pushes live now. The conf write and
     * the daemon re-arm are both debounced, so a scrub flurry collapses into one
     * write and one restart.
     */
    function commit(restart) {
        if (restart)
            root.pendingRestart = true;
        confTimer.restart();
        root.pushLive();
    }

    function notify(summary, body) {
        notifyProc.command = ["notify-send", "-a", "Ukishima", summary, body];
        notifyProc.running = true;
    }

    /** Check-only probe for the boot pass: is hyprsunset actually up? */
    readonly property var checkCmd: ["sh", "-c", "which hyprsunset >/dev/null 2>&1 && pgrep -x hyprsunset >/dev/null"]

    /**
     * Probe for a user click: confirm the binary, start the daemon through
     * systemd when it is down, then verify it came up.
     */
    readonly property var startCmd: ["sh", "-c", "which hyprsunset >/dev/null 2>&1 || exit 1\npgrep -x hyprsunset >/dev/null && exit 0\nsystemctl --user enable --now hyprsunset 2>/dev/null || systemctl --user start hyprsunset 2>/dev/null\nsleep 0.5\npgrep -x hyprsunset >/dev/null"]

    /**
     * Re-arm is needed whenever scheduled sits on either side of the change, so
     * the daemon never holds stale profiles that would override the new choice at
     * the next clock boundary. Pure off↔on rides the IPC push alone, since its
     * conf is a single all-day profile that only fires at 0:00.
     */
    function setMode(m) {
        if (m !== "off") {
            root.pendingMode = m;
            availProc.command = root.startCmd;
            availProc.running = true;
            return;
        }
        root.pendingMode = "";
        var was = Flags.nightLightMode;
        Flags.nightLightMode = m;
        root.commit(was === "scheduled" || m === "scheduled");
    }

    function applyMode(m) {
        var was = Flags.nightLightMode;
        Flags.nightLightMode = m;
        root.commit(was === "scheduled" || m === "scheduled");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: writer
        path: root.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: ipc
        command: []
        onExited: {
            var want = root.desiredCmd();
            if (want.join(" ") !== ipc.command.join(" ")) {
                ipc.command = want;
                ipc.running = true;
            }
        }
    }

    /** Debounced conf write, then a re-arm restart when a scheduled change asked for one. */
    Timer {
        id: confTimer
        interval: 250
        onTriggered: {
            writer.setText(root.buildConf());
            if (root.pendingRestart) {
                root.pendingRestart = false;
                restartProc.running = true;
            }
        }
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "hyprsunset"]
    }

    Process {
        id: availProc
        command: []
        onExited: function(exitCode) {
            root.available = (exitCode === 0);
            if (root.available && root.pendingMode !== "") {
                var m = root.pendingMode;
                root.pendingMode = "";
                root.applyMode(m);
            } else if (!root.available && root.pendingMode !== "") {
                root.pendingMode = "";
                root.notify("Night light unavailable", "hyprsunset is not installed or the service is not running.");
            }
        }
    }

    Process {
        id: notifyProc
        command: []
    }

    Component.onCompleted: {
        availProc.command = root.checkCmd;
        availProc.running = true;
    }
}
