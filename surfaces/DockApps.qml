pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"
import "../lib/fuzzy.js" as Fuzzy
import "../lib/apps.js" as Apps

/**
 * 品 DOCK APPS: the pinned app list with search, keyboard walk, and pin toggles.
 * Reached from DOCK SETTINGS and folds back on the back chevron or Esc.
 */
DockPanel {
    id: root

    backSurface: "dockSettings"
    implicitHeight: content.implicitHeight

    property string query: ""
    property int focusIndex: 0

    /** Every installed, displayable desktop entry — the launcher's own source,
     * so the two can never disagree about what is installed. */
    readonly property var allEntries: Apps.visibleApps(DesktopEntries.applications.values)

    /** The pins the dock can actually render, in dock order: each pin resolved
     * against the installed entries, unresolvable ones dropped. A pin whose app
     * was uninstalled still occupies a slot in DockPins.pins but contributes no
     * chip, so the dock's real order is this list and NOT the pins array. */
    readonly property var dockPins: {
        var out = [];
        for (var i = 0; i < DockPins.pins.length; i++) {
            var e = root.appById(DockPins.pins[i]);
            if (e)
                out.push(e.id);
        }
        return out;
    }

    /** The installed entry for a desktop-entry id, tolerating a .desktop suffix. */
    function appById(id) {
        if (!id)
            return null;
        var src = root.allEntries;
        var q = id.toLowerCase();
        for (var i = 0; i < src.length; i++) {
            if (src[i] && src[i].id && src[i].id.toLowerCase() === q)
                return src[i];
        }
        if (q.endsWith(".desktop")) {
            var bare = q.slice(0, -8);
            for (var j = 0; j < src.length; j++) {
                if (src[j] && src[j].id && src[j].id.toLowerCase() === bare)
                    return src[j];
            }
        }
        return null;
    }

    /** Pinned-first partition. Pinned entries are ordered by their position in
     * dockPins (read here, so the list re-partitions on any pin change — a pin,
     * an unpin or a drag-reorder in the dock); the rest sort by name. Within
     * each group the search's own ranking is preserved. */
    readonly property var appRows: {
        var hits = Fuzzy.rank(root.allEntries, root.query, {});
        var pinned = [];
        var rest = [];
        for (var i = 0; i < hits.length; i++) {
            var e = hits[i];
            var id = e && e.id ? e.id : "";
            if (id && root.dockPins.indexOf(id) >= 0)
                pinned.push(e);
            else
                rest.push(e);
        }
        pinned.sort(function (a, b) {
            return root.dockPins.indexOf(a.id) - root.dockPins.indexOf(b.id);
        });
        rest.sort(function (a, b) {
            return String(a.name || "").toLowerCase().localeCompare(String(b.name || "").toLowerCase());
        });
        return pinned.concat(rest);
    }

    /** How many chips the dock currently holds. Counts rendered chips, not
     * raw pins, so the number always matches the dock and the slot column. */
    readonly property int pinCount: root.dockPins.length

    /** Sub-caption for the dock settings index tile. */
    readonly property string pinSummary: DockPins.pins.length === 0
        ? "Choose which apps to pin"
        : DockPins.pins.length + (DockPins.pins.length === 1 ? " app pinned" : " apps pinned") + " · drag to reorder"

    function isPinned(id) {
        return !!id && DockPins.pins.indexOf(id) >= 0;
    }

    /** 1-based dock slot of a pinned entry, or -1. */
    function slotOf(id) {
        var i = root.dockPins.indexOf(id);
        return i >= 0 ? i + 1 : -1;
    }

    function togglePin(id) {
        if (id)
            DockPins.toggle(id);
    }

    /** Keyboard walk of the app list, and Enter to pin/unpin. */
    function moveAppFocus(dir) {
        var n = root.appRows.length;
        if (!n)
            return;
        root.focusIndex = Math.max(0, Math.min(n - 1, root.focusIndex + dir));
    }

    function activateAppFocus() {
        if (root.focusIndex < 0 || root.focusIndex >= root.appRows.length)
            return;
        var e = root.appRows[root.focusIndex];
        if (e && e.id)
            root.togglePin(e.id);
    }

    /** The picker's natural height: the sum of its rows' own heights. */
    readonly property real appsNaturalHeight: {
        var h = 0;
        for (var i = 0; i < appsBody.children.length; i++)
            if (appsBody.children[i]) h += appsBody.children[i].height;
        return h;
    }

    /** Window position of the last hover event allowed to move the highlight.
     * Rows sliding under a stationary cursor during keyboard scrolling repeat
     * the same window point and must not steal the selection. */
    property point lastPointer: Qt.point(-1, -1)

    rows: [
        { item: searchRow, kind: "raw" },
        { item: listFrame, kind: "raw" },
        { item: footerRow, kind: "raw" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            pal: root.pal
            glyph: "品"
            title: "APPS"
            showBack: true
        }

        Item { width: 1; height: 6 * root.s }

        // Search row
        Item {
            id: searchRow
            width: parent.width
            height: 28 * root.s

            Text {
                id: searchGlyph
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "探"
                color: root.dim
                font.family: Theme.fontJp
                font.weight: Theme.fontJpWeight
                font.pixelSize: 15 * root.s
            }

            TextField {
                id: appSearch
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 4 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                background: null
                padding: 0
                color: root.ink
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                placeholderText: "search applications"
                placeholderTextColor: root.faint
                selectByMouse: true
                selectionColor: root.accent
                onTextChanged: {
                    root.query = text;
                    root.focusIndex = 0;
                }
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.moveAppFocus(1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.moveAppFocus(-1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activateAppFocus();
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Escape) {
                        root.requestClose();
                        root.reportRowHover(appsTile, true);
                        e.accepted = true;
                    }
                }
            }

            Rectangle {
                anchors.left: appSearch.left
                anchors.right: appSearch.right
                anchors.top: appSearch.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: root.faint
                opacity: appSearch.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 8 * root.s }

        // App list frame
        Item {
            id: listFrame
            width: parent.width
            height: Math.min(appList.contentHeight, 260 * root.s)

            ListView {
                id: appList
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.appRows

                delegate: Item {
                    id: arow
                    required property int index
                    required property var modelData

                    readonly property string entryId: arow.modelData && arow.modelData.id ? arow.modelData.id : ""
                    readonly property bool pinned: root.isPinned(arow.entryId)
                    /** 1-based dock slot, or -1 when unpinned. */
                    readonly property int slot: root.slotOf(arow.entryId)
                    readonly property bool focused: root.focusIndex === arow.index
                    /** Name with the generic description as a quiet second
                     * line when it adds something the name does not say. */
                    readonly property string sub: {
                        var g = arow.modelData ? arow.modelData.genericName : "";
                        if (!g || g === arow.modelData.name)
                            return "";
                        return g;
                    }

                    width: ListView.view.width
                    height: arow.sub.length > 0 ? 44 * root.s : 36 * root.s

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (m) => {
                            var g = rowArea.mapToItem(null, m.x, m.y);
                            if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                                root.lastPointer = Qt.point(g.x, g.y);
                                root.focusIndex = arow.index;
                            }
                        }
                        onClicked: root.togglePin(arow.entryId)
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2 * root.s
                        anchors.bottomMargin: 2 * root.s
                        radius: 9 * root.s
                        color: arow.pinned
                            ? Qt.alpha(root.accent, 0.14)
                            : (arow.focused ? root.tile : "transparent")
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    // The icon and its backdrop are SIBLINGS, anchored to
                    // each other, exactly as in the launcher. Nesting the
                    // Image inside iconBg hid the two together: iconBg's
                    // `visible` is false precisely when the icon IS ready,
                    // so the icon was only ever drawn behind an invisible
                    // parent.
                    Rectangle {
                        id: iconBg
                        anchors.left: parent.left
                        anchors.leftMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22 * root.s
                        height: 22 * root.s
                        radius: 5 * root.s
                        color: Qt.rgba(1, 1, 1, 0.05)
                        visible: !(icon.status === Image.Ready && icon.source != "")
                    }

                    Image {
                        id: icon
                        anchors.fill: iconBg
                        sourceSize.width: Math.round(40 * root.s)
                        sourceSize.height: Math.round(40 * root.s)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready && source != ""
                        source: {
                            if (!arow.modelData || !arow.modelData.icon)
                                return "";
                            var ic = arow.modelData.icon;
                            // AppImage entries carry an absolute icon
                            // path; everything else is a theme name.
                            if (ic.indexOf("/") === 0)
                                return "file://" + ic;
                            return Quickshell.iconPath(ic, true);
                        }
                    }

                    // The text column ends at the pin switch, not at the
                    // slot number: anchoring to slotLabel.left left the
                    // name's box overlapping the ring by 2*s, so a long
                    // app name ran under the switch instead of eliding.
                    Text {
                        anchors.left: iconBg.right
                        anchors.leftMargin: 10 * root.s
                        anchors.right: pinRing.left
                        anchors.rightMargin: 8 * root.s
                        y: arow.sub.length > 0
                            ? iconBg.y - 1 * root.s
                            : parent.height / 2 - implicitHeight / 2
                        text: arow.modelData ? (arow.modelData.name || arow.entryId) : ""
                        color: arow.pinned ? root.accent : root.ink
                        font.family: Theme.font
                        font.pixelSize: 14 * root.s
                        font.weight: arow.pinned ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: arow.sub.length > 0
                        anchors.left: iconBg.right
                        anchors.leftMargin: 10 * root.s
                        anchors.right: pinRing.left
                        anchors.rightMargin: 8 * root.s
                        y: iconBg.y + 15 * root.s
                        text: arow.sub
                        color: root.faint
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        elide: Text.ElideRight
                    }

                    // Dock slot number: the pinned row's position in the
                    // dock, which is the order the drag-reorder writes.
                    // Sized by its own implicit width.
                    Text {
                        id: slotLabel
                        anchors.right: pinRing.left
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: arow.pinned
                        horizontalAlignment: Text.AlignRight
                        text: arow.slot > 0 ? String(arow.slot) : ""
                        color: root.accent
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                    }

                    // Pin switch: filled and tinted when the app is on the
                    // dock, an empty ring when it is not, so the whole row
                    // reads as a toggle and the click target needs no
                    // explanation.
                    Rectangle {
                        id: pinRing
                        anchors.right: parent.right
                        anchors.rightMargin: 14 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * root.s
                        height: width
                        radius: width / 2
                        color: arow.pinned ? root.accent : "transparent"
                        border.width: arow.pinned ? 0 : 1.2 * root.s
                        border.color: arow.pinned ? root.accent
                            : (arow.focused ? root.dim : root.faint)
                        opacity: arow.pinned ? 1 : 0.75
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }
                }
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: appList
            }
        }

        Item { width: 1; height: 6 * root.s }

        // Footer
        Item {
            id: footerRow
            width: parent.width
            height: 14 * root.s

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.pinCount > 0
                    ? root.pinCount + (root.pinCount === 1 ? " app pinned · " : " apps pinned · ") + "drag the dock icons to reorder"
                    : "pin apps here · drag the dock icons to reorder"
                color: root.faint
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                elide: Text.ElideRight
            }
        }

        Item { width: 1; height: 4 * root.s }
    }
}