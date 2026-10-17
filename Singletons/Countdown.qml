import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

/**
 * The pill's countdown clock, owned here rather than in the surface: the memory
 * saver unloads a closed surface after its tail, and a timer that dies with its
 * card is not a timer. It also means the end is announced through the
 * notification server with nothing open at all.
 *
 * One clock at a time. A preset is picked with `choose`, then `toggle`/`start`/
 * `pause`/`reset` drive it; at zero it notifies and parks back at the chosen
 * length, so the next start is one press away. Nothing here is persisted — a
 * daemon restart drops a running clock, which is the honest reading of a
 * session-scoped timer.
 */
Singleton {
    id: root

    /** Length the last pick asked for, in seconds; the tick returns here. */
    property int presetSec: 5 * 60

    /** Length the run in flight started from, so the meter cannot rescale
     *  under a mid-run pick: choosing while it counts only arms the next start. */
    property int armedSec: presetSec

    /** Seconds left on the clock; equals presetSec while it is parked. */
    property int remaining: presetSec

    property bool running: false

    /** Pick a length. While it runs the pick arms the next start instead. */
    function choose(sec) {
        root.presetSec = sec;
        if (!root.running) {
            root.remaining = sec;
            root.armedSec = sec;
        }
    }

    function start() {
        if (root.remaining <= 0) {
            root.remaining = root.presetSec;
            root.armedSec = root.presetSec;
        }
        root.running = root.remaining > 0;
    }

    function pause() {
        root.running = false;
    }

    function reset() {
        root.running = false;
        root.remaining = root.presetSec;
        root.armedSec = root.presetSec;
    }

    function toggle() {
        if (root.running)
            root.pause();
        else
            root.start();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            root.remaining = Math.max(0, root.remaining - 1);
            if (root.remaining <= 0) {
                root.running = false;
                notifyProc.command = ["notify-send", "-a", "Ukishima", "Timer", "Time's up"];
                notifyProc.running = true;
            }
        }
    }

    Process {
        id: notifyProc
    }
}
