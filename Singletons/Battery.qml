pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/**
 * Laptop-battery state for the pill, sourced from UPower's display device and
 * gated so a desktop without a battery reports `present` false (the hover
 * cluster and 蓄 surface stay hidden). Exposes percentage, charge state, a
 * signed draw/charge wattage, capacity and optional health, plus a formatted
 * time-to-empty/full string. `low` flags a discharging battery at or below 20%.
 * With UPower lacking cycle counts and design energy, those two are read from
 * /sys/class/power_supply (BAT* or battery) so the surface can show charge
 * cycles and a design-derived health even when UPower's own health is missing.
 */

Singleton {
    id: root

    readonly property var dev: UPower.displayDevice

    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property real frac: dev ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property int pct: Math.round(frac * 100)
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged || pct >= 100
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool low: !charging && pct <= 20

    readonly property real rateW: !dev ? 0
        : (discharging ? -dev.changeRate : (charging ? dev.changeRate : 0))
    readonly property real capacityWh: dev ? dev.energyCapacity : 0

    /**
     * Power profile, backed by power-profiles-daemon through Quickshell's own
     * PowerProfiles service — no extra process spawned. Mirrors the
     * performance/balanced/power-saver states the old waybar
     * powerprofile.sh / powerprofile-toggle.sh scripts cycled through, minus
     * the shell round-trip. `hasPerformance` gates offering Performance in
     * the UI, since power-profiles-daemon rejects setting it when the
     * hardware has no such profile (desktops, some laptops on battery-only
     * firmware).
     *
     * The service is a one-shot connect: Quickshell constructs its
     * PowerProfiles singleton on the first property access and, if D-Bus
     * activation fails then (a masked daemon), never retries — the entire
     * process is left with a dead connection. So the singleton is only
     * touched once `_attachPP` runs, which the daemon probe does only when it
     * reports "active". The first access then binds to the live daemon and
     * the picker works in-process — no shell reload or restart needed after
     * an in-surface enable.
     */
    property int profile: PowerProfile.Balanced
    readonly property bool powerSaver: root.profile === PowerProfile.PowerSaver
    readonly property bool performance: root.profile === PowerProfile.Performance
    property bool hasPerformance: true
    property bool _ppAttached: false

    /** First PowerProfiles access. Caller guarantees the daemon is active,
     *  so the singleton binds and mirrors into our plain properties. */
    function _attachPP() {
        if (root._ppAttached)
            return;
        root._ppAttached = true;
        PowerProfiles.profileChanged.connect(function () {
            root.profile = PowerProfiles.profile;
        });
        PowerProfiles.hasPerformanceProfileChanged.connect(function () {
            root.hasPerformance = PowerProfiles.hasPerformanceProfile;
        });
        root.profile = PowerProfiles.profile;
        root.hasPerformance = PowerProfiles.hasPerformanceProfile;
    }

    function setProfile(p) {
        if (root._ppAttached)
            PowerProfiles.profile = p;
        root.profile = p;
    }

    /** Same performance → balanced → power-saver → performance cycle as
     *  powerprofile-toggle.sh, for a keybind or a single-click chip. */
    function cycleProfile() {
        if (root.performance)
            root.setProfile(PowerProfile.Balanced);
        else if (root.powerSaver)
            root.setProfile(root.hasPerformance ? PowerProfile.Performance : PowerProfile.Balanced);
        else
            root.setProfile(PowerProfile.PowerSaver);
    }

    function togglePowerSaver() {
        root.setProfile(root.powerSaver ? PowerProfile.Balanced : PowerProfile.PowerSaver);
    }

    /** power-profiles-daemon reachability, probed once at startup and again
     *  after an in-surface enable. "active" is the only usable state; "masked"
     *  / "inactive" mean the unit exists but won't start; "missing" means the
     *  unit file itself is absent. */
    readonly property string daemonState: root._daemonState
    readonly property bool daemonReady: root._daemonState === "active"
    readonly property bool enabling: root._enabling
    property string _daemonState: "unknown"
    property bool _enabling: false

    function checkDaemon() {
        daemonProbe.running = true;
    }

    /** Prompt the user (pkexec → polkit) to unmask and start the daemon.
     *  No-ops when the unit isn't installed or its state is unknown — there
     *  is nothing to unmask/start, only the "not installed" note shows. */
    function enableDaemon() {
        if (root._enabling)
            return;
        if (root._daemonState === "missing" || root._daemonState === "unknown")
            return;
        root._enabling = true;
        daemonEnable.running = true;
    }

    /** Factory full-charge energy in Wh from sysfs; -1 when unreadable. */
    readonly property real energyFullDesign: root._energyFullDesign
    readonly property bool designSupported: root.energyFullDesign > 0

    readonly property bool hasTime: !dev ? false
        : (charging ? dev.timeToFull > 0 : (discharging ? dev.timeToEmpty > 0 : false))
    readonly property string timeStr: !dev ? ""
        : (charging ? fmt(dev.timeToFull) : (discharging ? fmt(dev.timeToEmpty) : ""))

    readonly property string stateLabel: charging ? "Charging"
        : (full ? "On AC · Full"
        : (discharging ? "Discharging" : "On AC"))

    property string batteryDir: ""
    property real _energyFullDesign: -1
    readonly property string batteryRoot: "/sys/class/power_supply"

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    Component.onCompleted: {
        findProc.running = true;
        daemonProbe.running = true;
    }

    /** Resolve which sysfs node is the battery, then read its health fields. */
    Process {
        id: findProc
        command: ["sh", "-c",
            "for d in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do "
            + "[ -d \"$d\" ] && printf '%s\\n' \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var dir = this.text.split("\n")[0].trim();
                if (!dir.length)
                    return;
                root.batteryDir = dir;
                sysfsReads.running = true;
            }
        }
    }

    Process {
        id: sysfsReads
        command: ["sh", "-c",
            "v=$(cat \"" + root.batteryDir + "/energy_full_design\" 2>/dev/null)"
            + " && printf 'energy_full_design=%s\\n' \"$v\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var val = this.text.replace(/^.*=(.*)\s*$/, "$1").trim();
                var n = parseFloat(val);
                root._energyFullDesign = isNaN(n) ? -1 : n / 1e6;
            }
        }
    }

    /** One-shot daemon reachability probe: is-active + is-enabled tell masked,
     *  disabled and installed-apart states apart. Re-run via checkDaemon() after
     *  an enable, so the surface flips to the live picker the moment the daemon
     *  answers. */
    Process {
        id: daemonProbe
        command: ["sh", "-c",
            "a=$(systemctl is-active power-profiles-daemon 2>/dev/null); "
            + "e=$(systemctl is-enabled power-profiles-daemon 2>/dev/null); "
            + "printf '%s|%s\\n' \"$a\" \"$e\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = this.text.trim().split("|");
                var active = out[0] || "";
                var enabled = out[1] || "";
                root._daemonState = active === "active" ? "active"
                    : enabled === "masked" ? "masked"
                    : enabled === "enabled" || enabled === "static" || enabled === "indirect" ? "inactive"
                    : /Failed|not[ -]found|No such|does not exist/i.test(enabled) ? "missing"
                    : "unknown";
                if (root._daemonState === "active")
                    root._attachPP();
            }
        }
    }

    /** Elevate for the unmask+enable. pkexec shows the polkit auth dialog; on
     *  exit (accepted or cancelled) re-probe so the UI reflects reality. A
     *  successful enable flips the probe to "active", whereupon the probe
     *  attaches the PowerProfiles singleton (`_attachPP`) — the first such
     *  access, so it binds to the now-live daemon. */
    Process {
        id: daemonEnable
        command: ["pkexec", "sh", "-c",
            "systemctl unmask power-profiles-daemon"
            + " && systemctl enable --now power-profiles-daemon"]
        onExited: function (exitCode) {
            root._enabling = false;
            root.checkDaemon();
        }
    }
}
