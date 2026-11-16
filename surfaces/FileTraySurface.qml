pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"
import "../lib/util.js" as Util

/**
 * File tray surface: the entries kept by reference in FileTray, as a single
 * horizontally scrolling strip of thumbnails, opened from the pill's tray icon.
 * Drop files or links anywhere on the card to add them, press + to browse, then
 * drag a tile into another app. A click copies the entry to the clipboard as
 * text/uri-list, so paste works even where dragging does not; double-click opens
 * it with xdg-open, and right-click (or the hover ✕) removes it.
 *
 * The chip row filters by entry kind (a tray holds files and links, not
 * folders), the magnifier swaps the chips for a search field, and the sort chip
 * cycles newest → name → type. Filtering and sorting live in FileTray so the
 * strip can never disagree with the counts.
 *
 * Scrolling follows the wallpaper strip: one wheel notch or trackpad swipe moves
 * one tile, the arrow keys and the arrows page a screenful, and the pointer can
 * flick the strip itself.
 *
 * Drag-out starts a real OS drag (`Drag.startDrag`) in TrayTile, which also
 * carries the click, double-click and remove handling.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 12

    property string notice: ""
    /** The search field takes over the chip row while it is open. */
    property bool searchOpen: false

    readonly property real rowH: 26 * root.s
    readonly property real tileW: 132 * root.s

    /** What the bottom bar says when there is no fresher notice. */
    readonly property string hint: FileTray.count === 0 ? ""
        : (FileTray.view.length === FileTray.count
            ? (FileTray.count === 1 ? "1 entry" : FileTray.count + " entries")
            : FileTray.view.length + " of " + FileTray.count)
          + " · drag out · click copies"

    readonly property string sortLabel: FileTray.sort === "name" ? "A-Z"
        : (FileTray.sort === "type" ? "Type" : "Recent")

    function notify(msg) {
        root.notice = msg;
        noticeTimer.restart();
    }

    /**
     * Which tile the keyboard or the wheel is on. The strip keeps it in view and
     * draws a ring on it; Enter opens it. Mirrors the wallpaper strip's
     * `focusIndex`, which is what the arrows drive there too.
     */
    property int focusIndex: 0

    /** Move the focus by `delta` tiles, clamped, and bring it into view. */
    function move(delta) {
        var n = FileTray.view.length;
        if (n === 0)
            return;
        root.focusIndex = Util.stepIndex(n, root.focusIndex, delta);
        view.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    /** One page of tiles; the bottom arrows and a page of wheel travel land here. */
    function page(delta) {
        var perPage = Math.max(1, Math.floor((view.width - 24 * root.s) / (root.tileW + view.spacing)));
        root.move(delta * perPage);
    }

    /** Open the focused entry with xdg-open, as a double-click does. */
    function activate() {
        if (root.focusIndex >= 0 && root.focusIndex < FileTray.view.length)
            FileTray.open(FileTray.view[root.focusIndex]);
    }

    function cycleSort() {
        FileTray.sort = FileTray.sort === "name" ? "recent" : (FileTray.sort === "recent" ? "type" : "name");
    }

    Timer {
        id: noticeTimer
        interval: 1400
        onTriggered: root.notice = ""
    }

    /** Every open starts clean: no stale filter, query or sort. */
    onActiveChanged: if (active) {
        root.notice = "";
        root.focusIndex = 0;
        root.searchOpen = false;
        search.text = "";
        FileTray.filter = "";
        FileTray.query = "";
        FileTray.sort = "recent";
    }

    /** Both the tray's own drop area and the pill's auto-open drop land here. */
    Connections {
        target: FileTray
        function onAdded(count) {
            root.notify(count === 0 ? "Nothing new added"
                : (count === 1 ? "File added" : count + " files added"));
        }
        function onCopied(ok) {
            root.notify(ok ? "Copied to clipboard" : "Clipboard copy failed");
        }
    }

    /**
     * The shell's focus scope routes the arrow keys here, exactly as it does for
     * the wallpaper strip (see shell.qml). When the search field is open it holds
     * active focus itself, so the arrows reach its text cursor and never the
     * strip.
     */
    onSearchOpenChanged: if (!root.searchOpen) search.input.focus = false

    /** Pill-shaped chip: a kind filter, or the browse button when it has no label. */
    component FilterChip: Rectangle {
        id: chip

        property real s: 1
        property string label: ""
        property string glyph: ""
        property color dot: Theme.vermLit
        property bool active: false
        property string tip: chip.label.length > 0
            ? (chip.active ? "Showing " + chip.label.toLowerCase() : "Show " + chip.label.toLowerCase())
            : ""
        signal clicked()

        readonly property color ink: chip.active ? Theme.cardTop : Theme.subtle

        height: 26 * chip.s
        width: chip.label.length > 0 ? body.implicitWidth + 24 * chip.s : height
        radius: height / 2
        color: chip.active ? Theme.cream : Qt.alpha(Theme.cream, 0.05)
        border.width: 1
        border.color: chip.active ? Theme.cream : Theme.hairSoft

        Row {
            id: body
            anchors.centerIn: parent
            spacing: 7 * chip.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.glyph.length > 0
                width: 12 * chip.s
                height: 12 * chip.s
                name: chip.glyph
                color: chip.ink
                stroke: 2
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label.length > 0
                width: 8 * chip.s
                height: 8 * chip.s
                radius: width / 2
                color: chip.dot
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label.length > 0
                text: chip.label
                color: chip.ink
                font.family: Theme.font
                font.pixelSize: 11 * chip.s
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

        Tooltip {
            s: chip.s
            placement: "below"
            show: chipArea.hovered && chip.tip.length > 0
            title: chip.tip
        }

        HoverHandler {
            id: chipArea
        }
    }

    Item {
        id: topRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.rowH

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            spacing: 7 * root.s
            visible: !root.searchOpen

            /* A chip for a kind the tray does not hold is noise, so it hides. */
            FilterChip {
                s: root.s
                visible: FileTray.fileCount > 0
                label: "Files"
                dot: Theme.vermLit
                active: FileTray.filter === "files"
                onClicked: FileTray.filter = active ? "" : "files"
            }

            FilterChip {
                s: root.s
                visible: FileTray.linkCount > 0
                label: "Links"
                dot: Theme.verm
                active: FileTray.filter === "links"
                onClicked: FileTray.filter = active ? "" : "links"
            }

            FilterChip {
                s: root.s
                glyph: "plus"
                tip: "Browse for files"
                onClicked: FileTray.browse()
            }
        }

        SearchField {
            id: search
            visible: root.searchOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            kanji: "棚"
            placeholder: "Search the tray"
            counterText: FileTray.view.length + " / " + FileTray.count
            onVisibleChanged: if (visible) Qt.callLater(search.input.forceActiveFocus)
            onTextChanged: FileTray.query = text
            onMoved: (d) => root.page(d)
            onAccepted: root.searchOpen = false
            onDismissed: root.searchOpen = false
        }
    }

    /**
     * The strip. Wheel and touchpad sit on their own click-through MouseArea,
     * exactly as in the wallpaper surface: a handler inside the view fights the
     * view's own wheel mapping, and one notch should always be one tile however
     * the device reports it.
     */
    ListView {
        id: view
        anchors.top: topRow.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bar.top
        anchors.bottomMargin: 7 * root.s
        orientation: ListView.Horizontal
        spacing: 6 * root.s
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: FileTray.view

        /* The strip glides to whatever the wheel or an arrow asked for rather
         * than jumping a tile. Tiles swallow the press (preventStealing), so
         * there is no flick to fight with here. */
        Behavior on contentX {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }

        delegate: TrayTile {
            required property string modelData
            required property int index
            s: root.s
            ready: root.settled
            focused: index === root.focusIndex
            path: modelData
            width: root.tileW
            height: view.height
            onFocusRequested: root.focusIndex = index
        }

        onCountChanged: root.focusIndex = Math.max(0, Math.min(root.focusIndex, count - 1))
    }

    MouseArea {
        id: wheelArea
        anchors.top: view.top
        anchors.bottom: view.bottom
        anchors.left: view.left
        anchors.right: view.right
        z: 20
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            /* Both axes go the same way here: a trackpad swipe up and a wheel
             * notch up both mean "back" in a single-row strip. */
            wheelArea.acc += (event.angleDelta.y + event.angleDelta.x) / 120;
            const notches = Math.trunc(wheelArea.acc);
            if (notches !== 0) {
                root.move(-notches);
                wheelArea.acc -= notches;
            }
            event.accepted = true;
        }
    }

    Text {
        anchors.top: view.top
        anchors.bottom: view.bottom
        anchors.left: view.left
        anchors.right: view.right
        visible: FileTray.view.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: FileTray.empty ? "Drop files or links here\nor press + to browse" : "Nothing matches"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        lineHeight: 1.45
    }

    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.rowH

        Row {
            id: nav
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root.s

            IconChip {
                s: root.s * 1.3
                glyph: "chevron-left"
                tooltipTitle: "Previous"
                onClicked: root.page(-1)
            }

            IconChip {
                s: root.s * 1.3
                glyph: "chevron-right"
                tooltipTitle: "Next"
                onClicked: root.page(1)
            }
        }

        Row {
            id: tools
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * root.s

            IconChip {
                s: root.s * 1.3
                glyph: "search"
                tooltipTitle: root.searchOpen ? "Close search" : "Search"
                onClicked: {
                    root.searchOpen = !root.searchOpen;
                    if (!root.searchOpen)
                        FileTray.query = "";
                }
            }

            IconChip {
                s: root.s * 1.3
                glyph: "sort"
                tooltipTitle: "Sort: " + root.sortLabel
                onClicked: root.cycleSort()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.sortLabel
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.features: { "tnum": 1 }
            }
        }

        Text {
            anchors.left: nav.right
            anchors.leftMargin: 10 * root.s
            anchors.right: tools.left
            anchors.rightMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.notice.length > 0 ? root.notice : root.hint
            color: root.notice.length > 0 ? Theme.vermLit : Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
        }
    }

    /**
     * Drop gateway. `keys` keeps an internal drag from being mistaken for a
     * file drop, and the tinted border answers the drag while it hovers.
     */
    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: (drag) => drag.acceptProposedAction()
        onDropped: (drop) => {
            drop.acceptProposedAction();
            FileTray.addDropped(drop.urls);
        }
    }

    /**
     * Drop highlight: a soft vermillion wash over the whole card while a drag
     * hovers it — no outline. Sits on top, so the wash reads across the chips
     * row and the tiles alike. The whole card takes the drop.
     */
    Rectangle {
        anchors.fill: parent
        visible: dropArea.containsDrag
        radius: 12 * root.s
        color: Qt.alpha(Theme.vermLit, 0.06)

        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }
}
