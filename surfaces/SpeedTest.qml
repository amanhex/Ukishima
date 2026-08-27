pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * Speed test surface: measures download, upload and ping using curl.
 * No external dependencies beyond curl. Shows animated progress and
 * final results in a clean card layout.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 16

    implicitHeight: content.implicitHeight

    property bool running: false
    property string phase: "" // "ping", "download", "upload", "done"
    property real pingMs: 0
    property real downloadMbps: 0
    property real uploadMbps: 0
    property string server: "Cloudflare"
    property int testIndex: 0

    readonly property var soulPoint: {
        void root.width;
        void root.height;
        if (Flags.showGlyphs)
            return kanji.mapToItem(root, kanji.width / 2, -3 * root.s);
        return speedLabel.mapToItem(root, -8 * root.s, speedLabel.height / 2);
    }

    ameForm: open ? "soul" : "off"
    amePoint: soulPoint

    function startTest() {
        if (root.running) return;
        root.running = true;
        root.phase = "ping";
        root.pingMs = 0;
        root.downloadMbps = 0;
        root.uploadMbps = 0;
        root.testIndex = 0;
        pingProc.running = true;
    }

    function stopTest() {
        root.running = false;
        root.phase = "";
        pingProc.running = false;
        dlProc.running = false;
        ulProc.running = false;
    }

    function fmtSpeed(mbps) {
        if (mbps >= 1000) return (mbps / 1000).toFixed(1) + " Gbps";
        return mbps.toFixed(1) + " Mbps";
    }

    Process {
        id: pingProc
        command: ["sh", "-c", "curl -s -o /dev/null -w '%{time_total}' https://speed.cloudflare.com/meta 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = parseFloat(this.text.trim()) || 0;
                root.pingMs = Math.round(t * 1000);
                root.phase = "download";
                dlProc.running = true;
            }
        }
    }

    Process {
        id: dlProc
        command: ["sh", "-c",
            "curl -s -o /dev/null -w '%{speed_download}' " +
            "https://speed.cloudflare.com/__down?bytes=10000000 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var bps = parseFloat(this.text.trim()) || 0;
                root.downloadMbps = Math.round(bps * 8 / 100000) / 10;
                root.phase = "upload";
                ulProc.running = true;
            }
        }
    }

    Process {
        id: ulProc
        command: ["sh", "-c",
            "dd if=/dev/urandom bs=1M count=5 2>/dev/null | " +
            "curl -s -o /dev/null -w '%{speed_upload}' -X POST -d @- " +
            "https://speed.cloudflare.com/__up 2>/dev/null || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var bps = parseFloat(this.text.trim()) || 0;
                root.uploadMbps = Math.round(bps * 8 / 100000) / 10;
                root.phase = "done";
                root.running = false;
            }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        width: parent.width
        spacing: 0

        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.s

                Text {
                    id: kanji
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "速"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    id: speedLabel
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SPEED TEST"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.server
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }
        }

        Item { width: 1; height: 16 * root.s }

        // Status / Start button
        Rectangle {
            width: parent.width
            height: 40 * root.s
            radius: 10 * root.s
            color: root.running ? Qt.alpha(Theme.vermLit, 0.12) : Theme.frameBg
            border.width: 1
            border.color: root.running ? Qt.alpha(Theme.vermLit, 0.3) : Theme.frameBorder

            Text {
                anchors.centerIn: parent
                text: root.running ? ("Testing " + root.phase + "...") :
                      root.phase === "done" ? "Tap to test again" : "Tap to start"
                color: root.running ? Theme.vermLit : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.running) root.stopTest();
                    else root.startTest();
                }
            }
        }

        Item { width: 1; height: 16 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Item { width: 1; height: 13 * root.s }

        // Results
        Item {
            width: parent.width
            height: 90 * root.s

            Row {
                anchors.fill: parent

                // Download
                Item {
                    width: parent.width / 3
                    height: parent.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "↓ Download"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.9 * root.s
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.downloadMbps > 0 ? root.fmtSpeed(root.downloadMbps) : "---"
                            color: root.phase === "download" ? Theme.vermLit : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14 * root.s
                            font.weight: Font.ExtraBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                // Ping
                Item {
                    width: parent.width / 3
                    height: parent.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Ping"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.9 * root.s
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.pingMs > 0 ? root.pingMs + " ms" : "---"
                            color: root.phase === "ping" ? Theme.vermLit : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14 * root.s
                            font.weight: Font.ExtraBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                // Upload
                Item {
                    width: parent.width / 3
                    height: parent.height

                    Column {
                        anchors.centerIn: parent
                        spacing: 4 * root.s

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "↑ Upload"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.Bold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.9 * root.s
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.uploadMbps > 0 ? root.fmtSpeed(root.uploadMbps) : "---"
                            color: root.phase === "upload" ? Theme.vermLit : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14 * root.s
                            font.weight: Font.ExtraBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
    }
}
