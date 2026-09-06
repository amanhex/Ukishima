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
    /** True once the background check has run and knows the remote state. */
    property bool checked: false
    /** Commits on origin/master that this checkout is behind. */
    property int pending: 0
    /** True when checked and origin/master has new commits to pull. */
    readonly property bool updateAvailable: checked && !busy && pending > 0

    rows: [
        { item: updateRow, kind: "activate", activate: function () { root.doUpdate(); } }
    ]

    Component.onCompleted: root.checkUpdates()

    /** Lightweight fetch + count so the surface can flag an available update. */
    function checkUpdates() {
        if (root.busy)
            return;
        fetchProc.running = true;
    }

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

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8 * root.s
                visible: root.updateAvailable
                width: 7 * root.s
                height: 7 * root.s
                radius: width / 2
                color: Theme.vermLit

                SequentialAnimation on opacity {
                    running: root.updateAvailable
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }

        Text {
            visible: root.updateAvailable
            width: parent.width
            color: Theme.vermLit
            text: "Update available · " + root.pending + (root.pending === 1 ? " commit" : " commits")
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            topPadding: 8 * root.s
        }

        Text {
            visible: root.checked && !root.updateAvailable && root.status.length === 0 && !root.busy
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "You're up to date"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            topPadding: 8 * root.s
        }

        Text {
            visible: root.status.length > 0 && !root.busy && root.status !== "Updated! Reloading..."
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
                root.pending = 0;
                root.checked = true;
                root.status = "Updated! Reloading...";
                reloadTimer.start();
            } else {
                root.status = "Update failed — check network";
            }
        }
    }

    /**
     * Non-blocking availability probe: refetch origin/master into the offset
     * ref then count how many of its commits this checkout is missing. A stale
     * remote-tracking ref is fine to read on open, but we refresh it first so
     * the badge reflects the true latest state. Network failure just leaves the
     * surface quiet — no error surfaced for a background check.
     */
    Process {
        id: fetchProc
        command: ["git", "-C", Config.configDir, "fetch", "--quiet", "origin", "master:refs/remotes/origin/update-probe"]
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.checked = true;
                root.pending = 0;
                return;
            }
            countProc.running = true;
        }
    }

    Process {
        id: countProc
        command: ["git", "-C", Config.configDir, "rev-list", "--count", "HEAD..refs/remotes/origin/update-probe"]
        onExited: function (exitCode, standardOutput) {
            root.checked = true;
            var n = parseInt(String(standardOutput).trim(), 10);
            root.pending = isNaN(n) ? 0 : n;
        }
    }

    Timer {
        id: reloadTimer
        interval: 1000
        onTriggered: Quickshell.reload(true)
    }
}
