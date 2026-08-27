pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 更新 UPDATE sub-surface: pulls the latest from GitHub and reloads the shell
 * in place. Reached from the Appearance index and folds back to it on the
 * back chevron or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    property string status: ""
    property bool busy: false

    rows: [
        { item: updateRow, kind: "activate", activate: function () { root.doUpdate(); } }
    ]

    function doUpdate() {
        if (root.busy)
            return;
        root.busy = true;
        root.status = "Pulling latest changes...";
        pullProc.running = true;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "更"
            title: "UPDATE"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: updateRow
            surface: root
            name: root.busy ? "Updating..." : (root.status.length > 0 ? root.status : "Check for updates")
            icon: "refresh-cw"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: root.busy ? "loader" : "download"
                color: root.focusRowItem === updateRow ? Theme.cream : Theme.iconDim
                stroke: 1.9

                RotationAnimation on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }
        }

        Text {
            visible: root.status.length > 0 && !root.busy
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.status
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
            topPadding: 8 * root.s
        }
    }

    Process {
        id: pullProc
        command: ["git", "-C", Config.configDir, "pull", "origin", "master"]
        onExited: function (exitCode) {
            root.busy = false;
            if (exitCode === 0) {
                root.status = "Updated! Reloading...";
                reloadTimer.start();
            } else {
                root.status = "Update failed — check network";
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 1000
        onTriggered: Quickshell.reload(true)
    }
}
