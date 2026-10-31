pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "../Singletons"
import "../components"
import "../lib/fuzzy.js" as Fuzzy
import "../lib/apps.js" as Apps

/**
 * 起 DOCK APP LAUNCHER: a wofi-style application menu that rises out of the dock.
 *
 * It is a DockPanel like every other dock page, so it inherits the dock's
 * backdrop, palette and intro slide instead of painting its own window. Two view
 * modes share one ranked result set, switched from the header seg:
 *
 *   - "list" (default): one wofi row per app — icon, name, generic description —
 *     with the pinned apps drawn first under a PINNED caption and the rest under
 *     ALL. Captions live inside the boundary rows, so a row index is always a
 *     result index and the keyboard walk needs no separate mapping.
 *   - "grid": the same results as a two-column tile grid, for pointing.
 *
 * Enter launches the focused app and closes. Right-click pins or unpins, exactly
 * as the app list in DOCK SETTINGS does, so the dock's order is edited from either.
 */
DockPanel {
    id: root
    Keys.onEscapePressed: (e) => {
        root.requestClose();
        e.accepted = true;
    }

    backSurface: ""
    implicitHeight: col.implicitHeight + (root.padTop + root.padBottom) * root.s
    /** Wider than a settings page: a two-column grid needs the room. */
    implicitWidth: 460 * root.s

    property string query: ""
    property int focusIndex: 0
    /** "list" or "grid". */
    property string view: "list"

    readonly property var allEntries: Apps.visibleApps(DesktopEntries.applications.values)

    /**
     * The dock's real pin order: each pin resolved against the installed entries,
     * unresolvable ones dropped. A pin whose app was uninstalled still holds a
     * slot in DockPins.pins but contributes no row, so the dock's order is this
     * and NOT the raw array (the same contract DOCK APPS uses).
     */
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
        var q = String(id).toLowerCase();
        for (var i = 0; i < src.length; i++)
            if (src[i] && src[i].id && src[i].id.toLowerCase() === q)
                return src[i];
        if (q.endsWith(".desktop")) {
            var bare = q.slice(0, -8);
            for (var j = 0; j < src.length; j++)
                if (src[j] && src[j].id && src[j].id.toLowerCase() === bare)
                    return src[j];
        }
        return null;
    }

    function isPinned(id) {
        return !!id && root.dockPins.indexOf(id) >= 0;
    }

    /**
     * Pinned first, each group keeping the fuzzy ranking's own order. Split rather
     * than sorted into one list so the list view can caption the two runs; the grid
     * just concatenates them back.
     */
    readonly property var ranked: Fuzzy.rank(root.allEntries, root.query, {})
    readonly property var pinnedRows: {
        var out = [];
        for (var i = 0; i < root.ranked.length; i++)
            if (root.isPinned(root.ranked[i].id))
                out.push(root.ranked[i]);
        out.sort(function (a, b) {
            return root.dockPins.indexOf(a.id) - root.dockPins.indexOf(b.id);
        });
        return out;
    }
    readonly property var restRows: {
        var out = [];
        for (var i = 0; i < root.ranked.length; i++)
            if (!root.isPinned(root.ranked[i].id))
                out.push(root.ranked[i]);
        return out;
    }
    /** The flat order both views draw and the keyboard walks: one entry per row. */
    readonly property var results: root.pinnedRows.concat(root.restRows)

    onQueryChanged: root.focusIndex = 0
    onViewChanged: root.focusIndex = 0
    onResultsChanged: if (root.focusIndex >= root.results.length) root.focusIndex = 0

    /** Window position of the last hover event allowed to move the highlight, shared
     *  by both delegates (see the guard in each MouseArea). */
    property point lastPointer: Qt.point(-1, -1)

    function launch(entry) {
        if (!entry)
            return;
        entry.execute();
        root.requestClose();
    }

    function activateFocus() {
        if (root.focusIndex >= 0 && root.focusIndex < root.results.length)
            root.launch(root.results[root.focusIndex]);
    }

    /** Arrow walk. One column in list mode, two in grid; wraps at every edge. */
    function moveFocus(dx, dy) {
        var n = root.results.length;
        if (n === 0)
            return;
        var cols = root.view === "grid" ? 2 : 1;
        var rows = Math.ceil(n / cols);
        var cur = Math.max(0, Math.min(n - 1, root.focusIndex));
        var nx = cur % cols + dx;
        var ny = Math.floor(cur / cols) + dy;
        if (nx < 0) nx = cols - 1;
        if (nx >= cols) nx = 0;
        if (ny < 0) ny = rows - 1;
        if (ny >= rows) ny = 0;
        root.focusIndex = Math.min(n - 1, ny * cols + nx);
        /* Bring the new focus into view; Contain scrolls the least it can. */
        if (root.view === "grid")
            grid.positionViewAtIndex(root.focusIndex, GridView.Contain);
        else
            appList.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    /** The Loader instantiates this page only when it opens, so this is the open hook. */
    Component.onCompleted: Qt.callLater(function () { search.forceActiveFocus(); })

    Column {
        id: col
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        /* The chevron is the way out: the panel's own header strip is the back
         * target and backSurface is empty, so a press there closes the launcher. */
        SettingsHeader {
            s: root.s
            pal: root.pal
            glyph: "起"
            title: "LAUNCH"
            showBack: true
        }

        Item { width: 1; height: 6 * root.s }

        /**
         * Search row: kanji, field, result counter and the list/grid seg. The field
         * keeps the keyboard, so every navigation key is handled here and the panel's
         * own row cursor is never involved.
         */
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

            SettingsSeg {
                id: viewSeg
                anchors.right: parent.right
                anchors.rightMargin: 2 * root.s
                anchors.verticalCenter: parent.verticalCenter
                s: root.s * 0.9
                pal: root.pal
                options: [
                    { label: "list", value: "list" },
                    { label: "grid", value: "grid" }
                ]
                value: root.view
                onPicked: (v) => {
                    root.view = v;
                    search.forceActiveFocus();
                }
            }

            TextField {
                id: search
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 4 * root.s
                anchors.right: counter.left
                anchors.rightMargin: 10 * root.s
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
                onTextChanged: root.query = text
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Down) {
                        root.moveFocus(0, 1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.moveFocus(0, -1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Right && root.view === "grid") {
                        root.moveFocus(1, 0);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Left && root.view === "grid") {
                        root.moveFocus(-1, 0);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.activateFocus();
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Escape) {
                        root.requestClose();
                        e.accepted = true;
                    }
                }
            }

            Text {
                id: counter
                anchors.right: viewSeg.left
                anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.results.length + " / " + root.allEntries.length
                color: root.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.features: { "tnum": 1 }
            }

            Rectangle {
                anchors.left: searchGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 4 * root.s
                anchors.right: counter.left
                anchors.rightMargin: 10 * root.s
                anchors.top: search.bottom
                anchors.topMargin: 3 * root.s
                height: 1
                color: root.faint
                opacity: search.activeFocus ? 0.7 : 0.18
                Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            }
        }

        Item { width: 1; height: 8 * root.s }

        /**
         * One frame for both modes. The list and the grid are the same model in two
         * layouts, so the frame, the empty-state text and the wheel scroller are
         * written once and only the delegate swaps.
         */
        Item {
            id: listFrame
            width: parent.width
            height: Math.min(root.view === "grid" ? grid.contentHeight : appList.contentHeight, 300 * root.s)

            Text {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: root.query.length > 0 ? "No matches" : "No apps found"
                color: root.faint
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }

            ListView {
                id: appList
                anchors.fill: parent
                visible: root.view === "list"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.results

                delegate: Item {
                    id: arow
                    required property var modelData
                    required property int index

                    readonly property bool pinned: root.isPinned(arow.modelData ? arow.modelData.id : "")
                    readonly property bool focused: root.focusIndex === arow.index
                    /**
                     * The caption sits on the row that starts a run: PINNED above the
                     * first pinned app, ALL above the first unpinned one (only when
                     * something is actually pinned to separate from).
                     */
                    readonly property string caption: arow.index === 0 && root.pinnedRows.length > 0
                        ? "PINNED"
                        : (root.pinnedRows.length > 0 && arow.index === root.pinnedRows.length
                            && root.restRows.length > 0 ? "ALL" : "")

                    width: appList.width
                    height: (arow.caption.length > 0 ? 22 * root.s : 0) + 36 * root.s

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6 * root.s
                        anchors.top: parent.top
                        anchors.topMargin: 7 * root.s
                        visible: arow.caption.length > 0
                        text: arow.caption
                        color: root.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.4 * root.s
                    }

                    Item {
                        id: rowBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: arow.caption.length > 0 ? 22 * root.s : 0
                        height: 36 * root.s

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            /* Rows sliding under a stationary cursor during keyboard
                             * scrolling repeat the same window point; the guard keeps
                             * that from stealing the keyboard selection. */
                            onPositionChanged: (m) => {
                                var g = rowArea.mapToItem(null, m.x, m.y);
                                if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                                    root.lastPointer = Qt.point(g.x, g.y);
                                    root.focusIndex = arow.index;
                                }
                            }
                            onClicked: (m) => {
                                if (m.button === Qt.RightButton) {
                                    if (arow.modelData && arow.modelData.id)
                                        DockPins.toggle(arow.modelData.id);
                                    return;
                                }
                                root.launch(arow.modelData);
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 1 * root.s
                            anchors.bottomMargin: 1 * root.s
                            radius: 9 * root.s
                            color: arow.focused ? root.tile : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Rectangle {
                            id: iconBg
                            anchors.left: parent.left
                            anchors.leftMargin: 11 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: 5 * root.s
                            visible: !(icon.status === Image.Ready && icon.source !== "")
                            color: Qt.rgba(1, 1, 1, 0.05)
                        }

                        Image {
                            id: icon
                            anchors.fill: iconBg
                            sourceSize.width: Math.round(40 * root.s)
                            sourceSize.height: Math.round(40 * root.s)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            visible: status === Image.Ready && source !== ""
                            source: {
                                if (!arow.modelData || !arow.modelData.icon)
                                    return "";
                                var ic = arow.modelData.icon;
                                /* AppImage entries carry an absolute icon path;
                                 * everything else is a theme name. */
                                if (ic.indexOf("/") === 0)
                                    return "file://" + ic;
                                return Quickshell.iconPath(ic, true);
                            }
                        }

                        Text {
                            anchors.left: iconBg.right
                            anchors.leftMargin: 10 * root.s
                            anchors.right: desc.left
                            anchors.rightMargin: 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: arow.modelData ? (arow.modelData.name || arow.modelData.id || "") : ""
                            color: arow.pinned ? root.accent : root.ink
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            font.weight: arow.pinned ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }

                        /** Generic description on the right, wofi-style. */
                        Text {
                            id: desc
                            anchors.right: pinDot.left
                            anchors.rightMargin: 12 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, rowBody.width * 0.42)
                            horizontalAlignment: Text.AlignRight
                            visible: text.length > 0
                            text: arow.modelData ? (arow.modelData.genericName || "") : ""
                            color: root.faint
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: pinDot
                            anchors.right: parent.right
                            anchors.rightMargin: 14 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7 * root.s
                            height: width
                            radius: width / 2
                            visible: arow.pinned
                            color: root.accent
                        }
                    }
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                visible: root.view === "grid"
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: width / 2
                cellHeight: 46 * root.s
                model: root.results

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool pinned: root.isPinned(tile.modelData ? tile.modelData.id : "")
                    readonly property bool focused: root.focusIndex === tile.index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: (m) => {
                            var g = tileArea.mapToItem(null, m.x, m.y);
                            if (g.x !== root.lastPointer.x || g.y !== root.lastPointer.y) {
                                root.lastPointer = Qt.point(g.x, g.y);
                                root.focusIndex = tile.index;
                            }
                        }
                        onClicked: (m) => {
                            if (m.button === Qt.RightButton) {
                                if (tile.modelData && tile.modelData.id)
                                    DockPins.toggle(tile.modelData.id);
                                return;
                            }
                            root.launch(tile.modelData);
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3 * root.s
                        radius: 10 * root.s
                        color: tile.focused ? root.tile : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 11 * root.s
                        anchors.rightMargin: 11 * root.s
                        spacing: 10 * root.s

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24 * root.s
                            height: 24 * root.s
                            sourceSize.width: Math.round(48 * root.s)
                            sourceSize.height: Math.round(48 * root.s)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            source: {
                                if (!tile.modelData || !tile.modelData.icon)
                                    return "";
                                var ic = tile.modelData.icon;
                                if (ic.indexOf("/") === 0)
                                    return "file://" + ic;
                                return Quickshell.iconPath(ic, true);
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34 * root.s
                            text: tile.modelData ? (tile.modelData.name || tile.modelData.id || "") : ""
                            color: tile.pinned ? root.accent : root.ink
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: tile.pinned ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 8 * root.s
                        anchors.rightMargin: 8 * root.s
                        width: 6 * root.s
                        height: width
                        radius: width / 2
                        visible: tile.pinned
                        color: root.accent
                    }
                }
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: root.view === "grid" ? grid : appList
            }
        }

        Item { width: 1; height: 6 * root.s }

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
                text: "↵ launch · right-click to pin · esc close"
                color: root.faint
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                elide: Text.ElideRight
            }
        }

        Item { width: 1; height: 4 * root.s }
    }
}
