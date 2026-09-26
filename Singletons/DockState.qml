pragma Singleton
import QtQuick
import Quickshell

/**
 * 空 Dock emptiness flag: the single source of truth for "does the dock have
 * anything to show" (pinned apps, running apps, or a frequent-app shelf).
 * `DockBar` publishes it after every item rebuild; the reserve window consults
 * it so the exclusive bottom band is released while the dock is retracted
 * empty — windows may then tile all the way down instead of floating above a
 * dead strip.
 */
Singleton {
    id: root

    property bool empty: true
}