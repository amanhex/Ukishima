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

    Component.onCompleted: findProc.running = true

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
}
