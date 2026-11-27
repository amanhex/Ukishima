pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import "."

/**
 * Full-screen Wi-Fi share card, ported from Omarchy's wifiqr panel.
 *
 * The matrix comes from scripts/wifi-qr.sh, which reads the active
 * NetworkManager profile and turns qrencode's ASCII output into 0/1 rows. The
 * card draws those rows as native rectangles, so the code stays crisp without
 * temporary images. It is deliberately a shell-level overlay rather than a pill
 * surface: a phone needs a QR much larger than the 272px Wi-Fi panel.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""
    property string iface: ""
    property bool active: false

    property string sharedIface: ""
    property string ssid: ""
    property string security: ""
    property bool secured: false
    property var qrRows: []
    property int qrSize: 0
    property bool loading: false
    property string error: ""
    property bool expectedStop: false
    property bool pendingGenerate: false
    property string password: ""
    property bool passwordVisible: false
    property string passwordError: ""
    property bool pwExpectedStop: false

    readonly property bool showingQr: root.qrSize > 0 && !root.loading && root.error === ""
    readonly property string title: root.ssid.length > 0 ? root.ssid : "Wi-Fi"
    readonly property color onScrim: "white"
    readonly property color onScrimDim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color onScrimUrgent: "#ff8a80"
    readonly property int qrTarget: Math.round(Math.min(300 * root.s, root.width * 0.5, root.height * 0.55))
    readonly property int moduleSize: root.qrSize > 0 ? Math.max(2, Math.floor(root.qrTarget / root.qrSize)) : 0
    readonly property int qrPx: root.moduleSize * root.qrSize

    visible: root.active || root.opacity > 0.01
    opacity: root.active ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    onActiveChanged: {
        if (root.active) {
            root.generate();
            Qt.callLater(keyCatcher.forceActiveFocus);
        } else {
            root.abort();
            root.password = "";
            root.passwordVisible = false;
            root.passwordError = "";
        }
    }

    onIfaceChanged: if (root.active) root.generate()

    function dismiss() {
        WifiShare.hide();
    }

    function reset() {
        root.qrRows = [];
        root.qrSize = 0;
        root.ssid = "";
        root.security = "";
        root.secured = false;
        root.error = "";
        root.loading = true;
        root.password = "";
        root.passwordVisible = false;
        root.passwordError = "";
        if (pwProc.running) {
            root.pwExpectedStop = true;
            pwProc.running = false;
        }
    }

    function generate() {
        if (qrProc.running) {
            root.pendingGenerate = true;
            root.expectedStop = true;
            qrProc.running = false;
            return;
        }
        root.pendingGenerate = false;
        root.expectedStop = false;
        root.reset();
        var args = ["bash", Config.hyprPath("scripts", "wifi-qr.sh"), "--meta"];
        if (root.iface.length > 0)
            args.push(root.iface);
        qrProc.command = args;
        qrProc.running = true;
    }

    function abort() {
        root.expectedStop = true;
        root.pendingGenerate = false;
        if (qrProc.running)
            qrProc.running = false;
        if (pwProc.running) {
            root.pwExpectedStop = true;
            pwProc.running = false;
        }
        root.qrRows = [];
        root.qrSize = 0;
        root.loading = false;
        root.error = "";
    }

    function applyOutput(raw) {
        var lines = String(raw || "").split("\n");
        var rows = [];
        var size = 0;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.length === 0)
                continue;
            if (line.indexOf("meta\t") === 0) {
                var parts = line.split("\t");
                root.sharedIface = parts[1] || "";
                root.security = parts[2] || "";
                root.ssid = parts.slice(3).join("\t");
                root.secured = root.security !== "" && root.security !== "nopass";
                continue;
            }
            if (!/^[01]+$/.test(line)) {
                root.error = "Could not read the QR matrix";
                root.qrSize = 0;
                root.qrRows = [];
                return;
            }
            if (size === 0)
                size = line.length;
            if (line.length !== size) {
                root.error = "The QR matrix is malformed";
                root.qrSize = 0;
                root.qrRows = [];
                return;
            }
            rows.push(line);
        }
        if (rows.length === 0) {
            if (root.error === "")
                root.error = "Could not read the QR matrix";
            root.qrSize = 0;
            root.qrRows = [];
            return;
        }
        root.qrRows = rows;
        root.qrSize = size;
        root.error = "";
    }

    function togglePassword() {
        if (root.passwordVisible) {
            root.passwordVisible = false;
            return;
        }
        if (root.password.length > 0) {
            root.passwordVisible = true;
            return;
        }
        if (pwProc.running || root.ssid.length === 0)
            return;
        root.passwordError = "";
        root.pwExpectedStop = false;
        pwProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk",
            "connection", "show", "id", root.ssid];
        pwProc.running = true;
    }

    Process {
        id: qrProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (!root.expectedStop) root.applyOutput(text)
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (!root.expectedStop) root.error = String(text || "").trim()
        }
        onExited: function(exitCode) {
            root.loading = false;
            if (root.pendingGenerate) {
                root.pendingGenerate = false;
                Qt.callLater(root.generate);
                return;
            }
            if (root.expectedStop) {
                root.expectedStop = false;
                return;
            }
            if (exitCode !== 0 || root.qrSize === 0) {
                root.qrSize = 0;
                root.qrRows = [];
                if (root.error === "")
                    root.error = "Could not generate the QR code";
            }
        }
    }

    Process {
        id: pwProc

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (root.active && !root.pwExpectedStop)
                root.password = String(text || "").trim()
        }
        onExited: function(exitCode) {
            if (root.pwExpectedStop || !root.active)
                return;
            if (exitCode === 0 && root.password.length > 0)
                root.passwordVisible = true;
            else
                root.passwordError = "Could not read the saved password";
        }
    }

    // ── Scrim and card ────────────────────────────────────────────────────

    FocusScope {
        id: keyCatcher

        anchors.fill: parent
        focus: root.active
        Keys.onEscapePressed: root.dismiss()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.82)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }

        Item {
            id: card

            anchors.centerIn: parent
            width: content.implicitWidth
            height: content.implicitHeight
            scale: Math.min(1,
                (root.width - 48 * root.s) / Math.max(1, width),
                (root.height - 48 * root.s) / Math.max(1, height))

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: content

                anchors.centerIn: parent
                spacing: 14 * root.s

                Text {
                    width: Math.min(320 * root.s, root.width * 0.72)
                    text: root.title.toUpperCase()
                    textFormat: Text.PlainText
                    color: root.onScrimDim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2 * root.s
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    id: qrCanvas

                    visible: root.showingQr
                    width: root.qrPx
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "white"
                    radius: 18 * root.s

                    Grid {
                        anchors.centerIn: parent
                        columns: root.qrSize
                        rows: root.qrSize
                        LayoutMirroring.enabled: false

                        Repeater {
                            model: root.qrSize * root.qrSize

                            Rectangle {
                                required property int index
                                readonly property int qrRow: Math.floor(index / root.qrSize)
                                readonly property int qrColumn: index % root.qrSize

                                width: root.moduleSize
                                height: root.moduleSize
                                color: {
                                    var row = root.qrRows[qrRow];
                                    if (!row || qrColumn >= row.length)
                                        return "transparent";
                                    return row.charAt(qrColumn) === "1" ? "#111111" : "transparent";
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.loading
                    text: "Generating QR code…"
                    textFormat: Text.PlainText
                    color: root.onScrimDim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.error !== ""
                    width: Math.min(320 * root.s, root.width * 0.72)
                    text: root.error
                    textFormat: Text.PlainText
                    color: root.onScrimUrgent
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.error !== ""
                    text: "Click to retry"
                    textFormat: Text.PlainText
                    color: root.onScrim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.underline: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.generate()
                    }
                }

                Text {
                    visible: root.showingQr
                    width: Math.min(320 * root.s, root.width * 0.72)
                    text: "Scan to join"
                    textFormat: Text.PlainText
                    color: root.onScrimDim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.showingQr && root.secured
                    width: Math.min(320 * root.s, root.width * 0.72)
                    text: root.passwordError !== "" ? root.passwordError
                        : root.passwordVisible ? root.password
                        : "Show password"
                    textFormat: Text.PlainText
                    color: root.passwordError !== "" ? root.onScrimUrgent : root.onScrim
                    opacity: root.passwordVisible || root.passwordError !== "" ? 1 : 0.58
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: root.passwordVisible ? Font.DemiBold : Font.Medium
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePassword()
                    }
                }

                Text {
                    visible: root.showingQr
                    width: Math.min(320 * root.s, root.width * 0.72)
                    text: "Esc or click outside to close"
                    textFormat: Text.PlainText
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 22 * root.s
            anchors.rightMargin: 24 * root.s
            width: 34 * root.s
            height: 34 * root.s

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }

            GlyphIcon {
                anchors.centerIn: parent
                width: 15 * root.s
                height: width
                name: "close"
                color: Qt.rgba(1, 1, 1, 0.72)
                stroke: 2
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss()
            }
        }
    }
}
