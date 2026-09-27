import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    LockContext {
        id: lockContext

        onUnlocked: {
            // fade surfaces out first, then release the lock + quit,
            // otherwise the compositor flashes a fallback screen
            lockContext.closing = true;
            quitTimer.start();
        }
    }

    Timer {
        id: quitTimer

        interval: 240
        repeat: false
        onTriggered: {
            lock.locked = false;
            Qt.quit();
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        WlSessionLockSurface {
            id: surf

            // opaque dark so the exit fade reveals black, never default white
            color: "#0b0d0c"

            LockSurface {
                anchors.fill: parent
                context: lockContext
                lockSurface: surf
            }

        }

    }

}
