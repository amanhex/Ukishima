pragma Singleton
import QtQuick
import Quickshell

/**
 * State for the Wi-Fi share card.
 *
 * The card is a shell-level overlay, not a pill surface: it must be readable by
 * a phone camera, which needs a much larger QR than the 272px Wi-Fi surface can
 * carry. The Wi-Fi surface raises it for the connected interface; the overlay
 * on that monitor draws it above the pill.
 */
Singleton {
    id: root

    property bool open: false
    property string monitor: ""
    property string iface: ""

    function show(mon, iface) {
        root.monitor = String(mon || "");
        root.iface = String(iface || "");
        root.open = true;
    }

    function hide() {
        root.open = false;
    }

    function toggle(mon, iface) {
        var m = String(mon || "");
        var i = String(iface || "");
        if (root.open && root.monitor === m && (i.length === 0 || root.iface === i)) {
            root.hide();
            return;
        }
        root.show(m, i);
    }
}
