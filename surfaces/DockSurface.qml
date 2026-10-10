pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"
import "../lib/fuzzy.js" as Fuzzy
import "../lib/apps.js" as Apps

/**
 * 泊 DOCK settings: the bottom app dock — its on/off switch and the dock's own
 * auto-hide, which apps are pinned, theme, glass depth and minimal flavour.
 *
 * This is a page of the DOCK's own settings panel (DockPanel), opened from the
 * gear chip at the right of the dock. It is deliberately not a pill surface any
 * more: it used to be reached from the pill's Appearance index and was drawn,
 * margined and coloured as part of the pill, so the pill's interface settings
 * governed how the dock's settings looked. Now the dock owns this page, and the
 * pill's surface stack does not mention it at all.
 *
 * The dock theme row offers the same four modes as the pill's Theme surface
 * (light / dark / dynamic / manual) because they are the same four modes, but
 * the two are fully segregated: manual renders locally from the dock's own hue
 * flags (PaletteHue), dynamic reads the shared wallpaper palette (Dyn) that only
 * wallpaper changes refresh, and light/dark are static. Switching the dock theme
 * never rewrites colors.json, so the pill stays untouched — and vice versa.
 *
 * The "Dock apps" row opens the app list IN PLACE, under the row: every
 * installed entry with a pin switch, searchable, its order set by dragging the
 * chips in the dock itself rather than from a list. It is a section of this page
 * rather than a second one — a separate page meant the dock's settings had a
 * two-level stack for a list that is one setting among the others.
 *
 * The "Dock" switch at the top is the one thing here that has a catch: it turns
 * this dock off, which slides the bar — and the gear that opened this panel —
 * off the bottom edge. It still works, because the panel is a sibling of the bar
 * in the window and does not travel with it, so the switch stays on screen and
 * is the way back. The shell keeps the panel clickable in that state; see
 * `dockForcedOpen` there.
 */
DockPanel {
    id: root

    implicitHeight: content.implicitHeight + padTop * root.s + padBottom * root.s

    /**
     * The panel's own geometry. These are the dock's numbers, not the pill's:
     * the dock's panel is narrower than the pill body and pads its own content,
     * because it no longer fills a pill inset by PillSurface's margins.
     */
    readonly property real panelW: 320
    implicitWidth: panelW * root.s
    readonly property real padTop: 14
    readonly property real padBottom: 12
    readonly property real padLeft: 16

    /** Current theme key; legacy "auto"/"transparent" saves read as dark. */
    readonly property string themeShown: (Flags.dockTheme === "auto"
        || Flags.dockTheme === "transparent") ? "dark" : Flags.dockTheme

    /** Sub-caption for the app-picker row: how many apps are pinned, so the
     *  door into the picker reports the state it would change. Reads
     *  DockPins.pins, so a pin made in the picker (or by right-clicking a chip)
     *  updates this caption live. */
    readonly property string pinSummary: DockPins.pins.length === 0
        ? "Choose which apps to pin"
        : DockPins.pins.length + (DockPins.pins.length === 1 ? " app pinned" : " apps pinned") + " · drag to reorder"
    //* The glass depth axis is independent; legacy saves default to transparent.
    readonly property string glassShown: Flags.dockStyle === "solid" ? "solid" : "transparent"

    /** Shorthands for this surface's own colour lookups. */
    readonly property color ink: root.pal ? root.pal.ink : "white"
    readonly property color faint: root.pal ? root.pal.faint : "gray"
    readonly property color dim: root.pal ? root.pal.dim : "gray"
    readonly property color accent: root.pal ? root.pal.accent : "gray"
    readonly property color tile: root.pal ? root.pal.tile : "transparent"

    // ---- which apps are on the dock ----
    // The picker is a section of THIS surface, not a page of its own: it is one
    // setting among the dock's others, and making it a separate page meant the
    // dock's settings had a two-level stack to navigate for no gain. Clicking
    // the "Dock apps" row opens the list in place, right there under the row.

    /** Whether the app list is expanded under its row. */
    property bool appsOpen: false

    property string query: ""
    property int focusIndex: 0

    /**
     * The picker's natural height: the sum of its rows' own heights. See the
     * note on `appsSection` — the Column's `implicitHeight` cannot be trusted
     * here because the panel keeps the whole tree invisible while closed.
     */
    readonly property real appsNaturalHeight: {
        var h = 0;
        for (var i = 0; i < appsBody.children.length; i++)
            if (appsBody.children[i]) h += appsBody.children[i].height;
        return h;
    }

    /**
     * Window position of the last hover event allowed to move the highlight.
     * Rows sliding under a stationary cursor during keyboard scrolling repeat
     * the same window point and must not steal the selection.
     */
    property point lastPointer: Qt.point(-1, -1)

    /** Every installed, displayable desktop entry — the launcher's own source,
     *  so the two can never disagree about what is installed. */
    readonly property var allEntries: Apps.visibleApps(DesktopEntries.applications.values)

    /**
     * The pins the dock can actually render, in dock order: each pin resolved
     * against the installed entries, unresolvable ones dropped. A pin whose app
     * was uninstalled still occupies a slot in DockPins.pins but contributes no
     * chip, so the dock's real order is this list and NOT the pins array. Using
     * pins.indexOf(id) + 1 for the slot number counted those phantom slots, so
     * every row below an uninstalled one showed a number one higher than the
     * position it actually occupies in the dock.
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

    /** The installed entry for a desktop-entry id, tolerating a .desktop suffix.
     *  Mirrors DockBar's own resolution, so a pin that the dock can show is a
     *  pin this list can count. */
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

    /**
     * Pinned-first partition. Pinned entries are ordered by their position in
     * dockPins (read here, so the list re-partitions on any pin change — a pin,
     * an unpin or a drag-reorder in the dock); the rest sort by name. Within
     * each group the search's own ranking is preserved.
     */
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

    /** How many chips the dock currently holds, echoed in the footer so the
     *  count and the reorder hint sit on one line. Counts rendered chips, not
     *  raw pins, so the number always matches the dock and the slot column. */
    readonly property int pinCount: root.dockPins.length

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

    /** Closing the list forgets the query, so reopening starts clean. */
    function setAppsOpen(v) {
        root.appsOpen = v;
        if (!v) {
            root.query = "";
            appSearch.text = "";
        } else {
            root.focusIndex = 0;
        }
    }

    // The dock's manual hue editor drives the dock's OWN flags only
    // (dockManualHue/dockManualSat/dockManualDark) — a live swatch for the
    // local PaletteHue render in DockBar.
    readonly property color accentColor: Qt.hsla(Flags.dockManualHue / 360, Flags.dockManualSat, Flags.dockManualDark ? 0.5 : 0.62, 1)
    readonly property string currentHex: Theme.hexUpper(accentColor)

    // Switching the dock theme only sets the flag; the dock re-resolves its own
    // palette locally (PaletteHue for manual, Dyn for dynamic, static hexes for
    // light/dark). No wallcolors process, no colors.json write — the pill never
    // notices. Picking dynamic refreshes the shared colors.json from the current
    // wallpaper first, so the dock's dynamic palette is never a stale cache.
    function applyMode(v) {
        Flags.dockTheme = v;
        if (v === "dynamic")
            paletteRegen.running = true;
    }

    /** Refresh the shared wallpaper palette (used by both dynamic sides) from the
     *  current wallpaper; everything writes only into the ukishima cache dir. */
    Process {
        id: paletteRegen
        command: ["bash", Config.hyprPath("scripts", "wallpaper.sh"), "regen"]
    }

    rows: {
        var base = [
            { item: dockRow, kind: "toggle", get: function () { return Flags.dockEnabled; }, set: function (v) { Flags.dockEnabled = v; } }
        ];
        // The dock sub-settings only exist while the dock itself is switched on.
        if (Flags.dockEnabled)
            base.push(
                { item: dockAutoHideRow, kind: "toggle", get: function () { return Flags.dockAutoHide; }, set: function (v) { Flags.dockAutoHide = v; } },
                // Door into the app picker: the list of every installed entry
                // with a pin switch per row. Membership only — the order is set
                // by dragging the chips in the dock. Sits third so the keyboard
                // order matches where the row actually is.
                { item: dockAppsRow, kind: "toggle", get: function () { return root.appsOpen; }, set: function (v) { root.setAppsOpen(v); } },
                { item: dockThemeRow, kind: "seg", vals: ["light", "dark", "dynamic", "manual"], get: function () { return root.themeShown; }, set: function (v) { root.applyMode(v); } },
                { item: dockGlassRow, kind: "seg", vals: ["transparent", "solid"], get: function () { return root.glassShown; }, set: function (v) { Flags.dockStyle = v; } },
                { item: dockMinimalRow, kind: "toggle", get: function () { return Flags.dockMinimal; }, set: function (v) { Flags.dockMinimal = v; } }
            );
        return base;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.topMargin: root.padTop * root.s
        anchors.left: parent.left
        anchors.leftMargin: root.padLeft * root.s
        anchors.right: parent.right
        anchors.rightMargin: root.padLeft * root.s
        spacing: 0

        SettingsHeader {
            s: root.s
            pal: root.pal
            glyph: "泊"
            title: "DOCK"
            /* The cog, not a back chevron: the dock's settings are a single
             * page now, so there is no level to go back to — the header is
             * closing the panel, and it echoes the gear that opened it. */
            showBack: false
        }

        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: dockRow
            surface: root
            name: "Dock"
            icon: "dock"
            last: !Flags.dockEnabled

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockEnabled
                onToggled: Flags.dockEnabled = !Flags.dockEnabled
            }
        }

        SettingsRow {
            id: dockAutoHideRow
            surface: root
            name: "Dock auto-hide"
            icon: "eye-off"
            visible: Flags.dockEnabled

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockAutoHide
                onToggled: Flags.dockAutoHide = !Flags.dockAutoHide
            }
        }

        /**
         * The air the dock keeps between itself and the windows that tile
         * above it, as a percentage of the shipped 12px: 100% is the shipped
         * gap, 0% tucks the windows flush under the dock — pickable as four
         * fixed steps, like the pill's Window gap row. Its own flag,
         * separate from the pill's, so the two bars' gaps can differ.
         * Hidden under auto-hide: the dock then reserves no band at all, so
         * the gap it would describe does not exist either.
         */
        SettingsRow {
            id: dockGapRow
            surface: root
            name: "Window gap"
            icon: "monitor"
            visible: Flags.dockEnabled && !Flags.dockAutoHide

            SettingsSeg {
                s: root.s
                pal: root.pal
                options: [{ label: "25%", value: 0.25 }, { label: "50%", value: 0.5 }, { label: "100%", value: 1 }, { label: "150%", value: 1.5 }]
                value: Flags.dockGap
                onPicked: (v) => Flags.dockGap = v
            }
        }

        /**
         * Which apps are on the dock. Sits with the dock's CONTENT rows, above
         * the theme block, because it used to land between the theme row and
         * the manual hue section that belongs to it — splitting a row from its
         * own sub-section. It also carried no `icon`, so unlike every sibling
         * its label started at the far left and read as unaligned.
         */
        SettingsRow {
            id: dockAppsRow
            surface: root
            name: "Dock apps"
            sub: root.pinSummary
            icon: "app-window"
            visible: Flags.dockEnabled

            /**
             * A disclosure, not a door. The chevron turns down when the list is
             * open, which is the whole feedback for a click that opens a section
             * in place rather than another page.
             */
            Item {
                width: 16 * root.s
                height: 16 * root.s

                GlyphIcon {
                    id: appsChevron
                    anchors.centerIn: parent
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "chevron-down"
                    stroke: 1.9
                    color: root.focusRowItem === dockAppsRow ? root.ink : root.dim
                    opacity: root.appsOpen ? 1 : 0.75
                    rotation: root.appsOpen ? 0 : -90
                    Behavior on rotation {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                    }
                }
            }
        }

        /**
         * The app list, in place under its row. It animates its own height so
         * the panel grows and shrinks around it instead of jumping, and the
         * frame is capped so a long list cannot push the panel off the top of
         * the screen — the list scrolls inside it.
         *
         * Height summed from the rows' OWN heights, not read off the Column's
         * `implicitHeight`. While the panel is closed the whole tree is
         * invisible, a Column computes its implicitHeight once in that state
         * and never re-measures when it becomes visible again — so the stale
         * 24px (just the four `width:1` spacers) won the binding, the section
         * opened to 24px, and everything below the search box was clipped away.
         * Every row here has an explicit height, so the sum is valid hidden or
         * not. Verified: plain Column = 326, the same Column under a
         * `visible: height > 0` parent = stuck.
         */
        Item {
            id: appsSection
            width: parent.width
            height: root.appsOpen ? root.appsNaturalHeight : 0
            clip: true
            visible: height > 0
            Behavior on height {
                NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
            }

            onHeightChanged: if (height === 0) {
                root.query = "";
                appSearch.text = "";
            }

            /**
             * Take the keyboard here, not from `setAppsOpen`: the section opens
             * with an animated height, so a call posted right after `appsOpen`
             * flips still lands while `height` is 0 and `visible` false, and a
             * focus call on an invisible item is dropped. This fires on the tick
             * the section actually exists.
             */
            onVisibleChanged: if (visible) appSearch.forceActiveFocus()

            Column {
                id: appsBody
                width: parent.width
                spacing: 0

                Item { width: 1; height: 6 * root.s }

                Item {
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
                                // Escape collapses the list and gives the row
                                // its focus back, so the keyboard never gets
                                // stranded inside a section it cannot leave.
                                //
                                // Through `reportRowHover`, not by assigning
                                // `root.kbIndex` / `root.focusRowItem`: those
                                // are READ-ONLY aliases of `nav` on DockPanel,
                                // so the direct assignment threw a TypeError
                                // and the row never got its focus back.
                                // reportRowHover is the same call the pointer
                                // makes to park the cursor on a row.
                                root.setAppsOpen(false);
                                root.reportRowHover(dockAppsRow, true);
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

                Item {
                    id: appListFrame
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
                             *  line when it adds something the name does not say. */
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
                            // Sized by its own implicit width — binding `width` to
                            // `implicitWidth` made QML report a binding loop on
                            // every row, because for an anchored Text the two
                            // properties feed each other.
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

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 6 * root.s
                    text: root.pinCount > 0
                        ? root.pinCount + (root.pinCount === 1 ? " app pinned · " : " apps pinned · ") + "drag the dock icons to reorder"
                        : "pin apps here · drag the dock icons to reorder"
                    color: root.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    elide: Text.ElideRight
                }

                Item { width: 1; height: 4 * root.s }
            }
        }

        SettingsRow {
            id: dockThemeRow
            surface: root
            name: "Dock theme"
            icon: "palette"
            visible: Flags.dockEnabled

            SettingsSeg {
                s: root.s
                pal: root.pal
                options: [{ label: "Light", value: "light" }, { label: "Dark", value: "dark" }, { label: "Dynamic", value: "dynamic" }, { label: "Manual", value: "manual" }]
                value: root.themeShown
                onPicked: (v) => root.applyMode(v)
            }
        }

        /**
         * Manual hue editor, folded shut unless the dock theme is on Manual. Holds a
         * rainbow strip with a draggable thumb, then a single line pairing a live
         * accent swatch and its hex caption with the dark/light choice, and a hex
         * input that drives both hue and saturation. Mirrors the pill's Theme
         * surface so the dock can be rice-coloured independently of the pill.
         */
        Item {
            id: manualSection
            width: parent.width
            height: (Flags.dockEnabled && Flags.dockTheme === "manual") ? manualCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

            Column {
                id: manualCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4 * root.s
                anchors.rightMargin: 4 * root.s
                topPadding: 4 * root.s
                bottomPadding: 16 * root.s
                spacing: 14 * root.s

                HueStrip {
                    s: root.s
                    hue: Flags.dockManualHue
                    sat: Flags.dockManualSat
                    thumbColor: root.accentColor
                    thumbBorder: root.pal ? root.pal.ink : "white"
                    onSatSeeded: Flags.dockManualSat = 0.5
                    onHuePicked: (h) => Flags.dockManualHue = h
                }

                Item {
                    width: parent.width
                    height: Math.max(34 * root.s, toneSeg.implicitHeight)

                    Rectangle {
                        id: accentSwatch
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.s
                        height: 34 * root.s
                        radius: 9 * root.s
                        color: root.accentColor
                        border.width: 1
                        border.color: root.pal ? root.pal.edge : "gray"
                    }

                    Column {
                        anchors.left: accentSwatch.right
                        anchors.leftMargin: 12 * root.s
                        anchors.right: toneSeg.left
                        anchors.rightMargin: 12 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3 * root.s

                        Text {
                            text: "Accent hue"
                            color: root.pal ? root.pal.ink : "white"
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.currentHex + " · " + (Flags.dockManualDark ? "dark" : "light")
                            color: root.pal ? root.pal.faint : "gray"
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.features: { "tnum": 1 }
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SettingsSeg {
                        id: toneSeg
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        pal: root.pal
                        options: [{ label: "Dark", value: true }, { label: "Light", value: false }]
                        value: Flags.dockManualDark
                        onPicked: (v) => { Flags.dockManualDark = v; }
                    }
                }

                HexField {
                    s: root.s
                    placeholder: root.currentHex
                    ink: root.pal ? root.pal.ink : "white"
                    faint: root.pal ? root.pal.faint : "gray"
                    accent: root.pal ? root.pal.accent : "gray"
                    onCommitted: (hue, sat) => {
                        if (hue >= 0) {
                            Flags.dockManualHue = hue;
                            Flags.dockManualSat = sat;
                        } else {
                            Flags.dockManualSat = 0;
                        }
                    }
                }
            }
        }

        SettingsRow {
            id: dockGlassRow
            surface: root
            name: "Dock glass"
            icon: "droplet"
            visible: Flags.dockEnabled

            SettingsSeg {
                s: root.s
                pal: root.pal
                options: [{ label: "Transparent", value: "transparent" }, { label: "Solid", value: "solid" }]
                value: root.glassShown
                onPicked: (v) => Flags.dockStyle = v
            }
        }

        SettingsRow {
            id: dockMinimalRow
            surface: root
            name: "Minimal dock"
            icon: "dot"
            visible: Flags.dockEnabled
            last: Flags.dockEnabled

            LinkToggle {
                s: root.s
                pal: root.pal
                on: Flags.dockMinimal
                onToggled: Flags.dockMinimal = !Flags.dockMinimal
            }
        }
    }

    /**
     * The header strip closes the panel. On the pill this gesture is handled
     * one level up by the surface stack; the dock's panel is the top of its
     * own stack, so the close belongs to the page.
     *
     * A SIBLING of the content Column, not a child of it: as a child the Column
     * laid this out as its own 22px row — Column overrides a child's `y`, so the
     * offset it was given did nothing and the strip pushed every row 22px
     * further from the title. Anchored to the top instead, it covers the pad and
     * the header and costs the layout nothing.
     */
    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: (root.padTop + 22) * root.s
        z: 1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestClose()
    }
}