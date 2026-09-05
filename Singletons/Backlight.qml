pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * One shared event-driven watcher for the internal laptop backlight. Every pill
 * carries an Osd, so watching here keeps it a single watcher instead of one per
 * monitor. A `udevadm monitor` on the backlight subsystem delivers a KERNEL
 * uevent on every brightness write; the matching line triggers a single sysfs
 * read. `changed` fires only when the value actually moved, so the initial
 * populate and irrelevant events never flash the OSD. The watcher is respawned
 * (capped) if it ever exits instead of polling on a timer.
 */
Singleton {
    id: root

    property bool present: false
    property real brightness: 0
    property int lastPct: -1

    signal changed()

    /** Respawn budget; reset by `stableReset` once the watcher has stayed live. */
    property int restartCount: 0

    Timer {
        id: restartGrace
        interval: 1500
        onTriggered: {
            if (root.present && !monitor.running)
                monitor.running = true;
        }
    }

    Timer {
        id: stableReset
        interval: 60000
        repeat: true
        running: root.present
        onTriggered: root.restartCount = 0
    }

    Process {
        id: monitor
        command: ["sh", "-c",
            "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); [ -n \"$dev\" ] || exit 0;" +
            "d=/sys/class/backlight/$dev; max=$(cat $d/max_brightness);" +
            "PARENT=$PPID; ( while [ -d /proc/$PARENT ]; do sleep 3; done;" +
            "  kill -TERM $(pgrep -x udevadm) 2>/dev/null; kill -TERM \"$$\" 2>/dev/null ) &" +
            "echo \"$(( $(cat $d/brightness) * 100 / max ))\";" +
            "udevadm monitor --subsystem-match=backlight | while IFS= read -r l; do" +
            "  case \"$l\" in" +
            "    KERNEL*\"/$dev (backlight)\")" +
            "      v=$(cat $d/brightness 2>/dev/null); case \"$v\" in *[!0-9]*|'') continue;; esac;" +
            "      echo \"$(( v * 100 / max ))\";;" +
            "  esac;" +
            "done"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                var pct = parseInt(line.trim(), 10);
                if (isNaN(pct))
                    return;
                var seen = root.lastPct >= 0;
                root.present = true;
                root.brightness = Math.max(0, Math.min(100, pct)) / 100.0;
                root.lastPct = pct;
                if (seen)
                    root.changed();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        onExited: {
            if (!root.present || root.restartCount >= 5)
                return;
            root.restartCount++;
            restartGrace.start();
        }
    }
}
