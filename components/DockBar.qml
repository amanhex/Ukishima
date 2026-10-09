pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../lib/apps.js" as Apps
import "../Singletons"

/**
 * macOS-style bottom dock: a floating washi bar showing the pinned apps in
 * their user-chosen order, then a hairline divider, then every running app
 * that is not already pinned. Clicking a running app focuses its window
 * (workspace switch included), clicking a closed one launches its desktop
 * entry; right-click toggles the pin. A window whose class cannot be resolved
 * to a desktop entry still appears while running (icon from the theme) but
 * cannot be pinned, since there is nothing to re-launch.
 *
 * With nothing pinned and nothing running, the bar becomes a shelf of the five
 * most-launched apps from the launcher's usage log (click to launch,
 * right-click to pin — which teaches the affinity with one gesture). With no
 * usage history at all the dock retracts entirely and releases its reserved
 * band (see `empty` / DockState).
 *
 * Pins live in the same state file pattern as launcher usage counts
 * (ukishima/dock-pins.json, an ordered JSON array of desktop entry ids), so
 * they survive restarts and are shared by every monitor's dock. The item list
 * is rebuilt on an interval and whenever pins change, because the toplevel
 * model's .values is not reliably notifiable.
 *
 * Pinned chips can be dragged sideways to reorder them, so the dock's order is
 * purely the user's own liking (see `beginDrag` / `slotForX`). Only pinned
 * chips move: a running-but-unpinned chip has no place in the persistent order,
 * and it is a click target. The unpinned shelf below the divider takes a
 * stable first-seen session order (DockState) instead of a workspace order, so
 * it does not reshuffle as windows travel between workspaces.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""

    /**
     * Reveal collaboration with the shell window: `hovered` is fed by a
     * window-level HoverHandler (pointer events only exist inside the input
     * mask, so "hovered" means "over whatever the dock currently claims"), and
     * `revealSession` is latched while the pointer is over the dock and
     * released on a grace delay after it leaves, exactly like the pill's.
     *
     * While the settings panel is open the mask is the panel and the bar
     * together, so this same flag reads as "over the panel or the bar" and the
     * panel's click-away is a second consumer of it rather than a parallel
     * watch. See `revealTimer` below.
     */
    property bool hovered: false
    property bool revealSession: false

    /** Fed by shell.qml: surface open / monitor fullscreen / game mode. */
    property bool suppressed: false

    /**
     * The dock's own settings panel, opened from the gear chip below. It is one
     * page, not a stack: the app picker used to be a second surface reached by
     * a nav row, but it is one setting among the dock's others, so it now opens
     * in place under its own row and there is nothing to navigate between.
     *
     * The panel itself is NOT a child of this item. The shell hosts it as a
     * sibling, because this bar is translated off the bottom edge when the dock
     * is disabled — a panel inside it would slide away and take the "Dock"
     * switch with it, stranding anyone who turned the dock off from inside its
     * own settings with no way back. Only the open/closed state is owned here;
     * the shell draws and places the panel.
     */
    property bool settingsOpen: false

    /** The gear's action, and the only way in or out of the panel. */
    function toggleSettings() {
        if (root.settingsOpen)
            root.closeSettings();
        else
            root.openSettings();
    }

    function openSettings() {
        root.settingsOpen = true;
    }

    function closeSettings() {
        root.settingsOpen = false;
    }

    /**
     * Auto-hide must not retract the bar out from under its own open panel: the
     * gear is the panel's visible close affordance, and a bar that slid away
     * would leave the panel floating over an empty strip of screen.
     *
     * This says nothing about `suppressed` — the dock being switched off slides
     * the bar whatever the panel is doing, on purpose. The panel is a sibling of
     * this item in the window, so it stays put and the "Dock" switch inside it
     * remains the way back.
     */
    readonly property bool hidden: Flags.dockAutoHide && !revealSession && !hovered && !settingsOpen

    /** The bar is down (retracted or suppressed) and its contents are inert. */
    readonly property bool down: hidden || suppressed

    /**
     * True while the chip delegates have been dropped. Clearing `itemsModel`
     * destroys every chip object tree, which is worth roughly 6 MiB of heap, and
     * it also lets the poll above stop asking what the session looks like for a
     * bar nobody can see.
     *
     * Six MiB is the honest figure, and it is worth being exact about where the
     * larger one comes from, because this is easy to measure wrong. A dock reads
     * as 26 MiB heavier than the same dock with its chips suppressed — but 20 MiB
     * of that is `NotoSansCJK-Regular.ttc`, mapped the first time a chip renders
     * text. A font is held by Qt's font database for the life of the process, so
     * dropping the delegates does not give it back and neither would tearing the
     * whole component down; anything else on screen rendering CJK maps it just
     * the same. What is left over is the object tree, and that is what this drops.
     *
     * The component itself stays alive deliberately. Its compiled form and the
     * desktop-entry snapshot it reads are a rounding error beside the number
     * above, and keeping the instance means the shell window's input mask, reveal
     * chain and settings panel go on reading exactly what they always read. Those
     * are the most interdependent bindings in the shell, and this change does not
     * touch one of them.
     *
     * `down`, rather than visibility generally. An `empty` dock has no delegates
     * to drop, so reclaiming one would save nothing, and skipping it is also what
     * keeps a reclaimed dock recoverable. `down` clears from outside this
     * component — the shell window's hover feed on reveal, a monitor leaving
     * fullscreen, a surface opening, the flag being switched back on — whereas
     * only the poll in `refreshItems` can make an `empty` dock non-empty, and the
     * poll is exactly what reclaim stops. A dock reclaimed under `down` always has
     * a way back; one reclaimed while `empty` could never come back at all.
     */
    property bool reclaimed: false

    /**
     * The `itemSig` value meaning "the delegates are gone, rebuild them". A real
     * signature is assembled from window and pin state and can legitimately be
     * empty — no toplevels and no pins — so neither `""` nor `null` will do: QML
     * coerces `null` to `""` for a string property, which is also the value the
     * dock starts on. A NUL cannot occur in a signature built from these fields,
     * so nothing can match it and the next refresh always rebuilds.
     */
    readonly property string droppedSig: "\u0000"

    readonly property bool minimal: Flags.dockMinimal

    /** Inline title row under the icons (full mode only); minimal is icon + dot. */
    readonly property bool titled: !Flags.dockMinimal

    readonly property real dockH: (minimal ? 58 : 68) * s
    /* Full mode carries a label under the icon, so its chips are wider than
     * minimal's: at 58 the label box was 52px — about nine characters — and
     * every real name ("MissionCenter", "RQuickShare") elided. 68 gives the
     * label 62px. The drag step is derived from chipW, so the wider chip moves
     * the drop slots with it rather than needing its own constant. */
    readonly property real chipW: (minimal ? 56 : 68) * s
    readonly property int chipSpacing: 2

    // ---- pinned-chip drag reorder ----
    // Dragging a pinned chip rewrites the shared pins array, so the order is
    // the user's own liking and every monitor's dock follows through DockPins.
    // Only pinned chips are draggable: an unpinned running chip has no place in
    // the persistent order, and it is a click target, so it keeps plain clicks.
    //
    // `dragFrom`/`dragTo` are RUN SLOTS (0-based positions in the leading run
    // of pinned chips, which are also their model indices), not pins-array
    // indices. The two differ whenever a pin's desktop entry has gone missing:
    // that pin still occupies a slot in the array but contributes no chip, so
    // the run is shorter than the array. Slots drive the geometry and the drop
    // marker; the run slot is translated to a pins index only at commit.
    /** Run slot of the chip being dragged, or -1 when no drag is in flight. */
    property int dragFrom: -1
    /** Run slot the dragged chip would land on if released now. */
    property int dragTo: -1
    /** True once the pointer passed the drag threshold, i.e. this is a reorder
     *  and not a click. Stays false for a press-and-release in place. */
    property bool dragMoved: false
    readonly property bool dragActive: root.dragFrom >= 0 && root.dragMoved
    /** Horizontal travel in root pixels before a press counts as a drag. */
    readonly property real dragThreshold: 8 * s
    property real dragPressX: 0

    /**
     * The pinned section is a contiguous run of equal-width chips at the front
     * of the row, so a pointer position maps to a run slot by arithmetic rather
     * than hit-testing.
     *
     * One step is a chip plus its gap, and because the row starts at x=0 the
     * step lands on each chip's own left edge — so plain rounding puts the
     * switch exactly at each chip's CENTRE, which is the rule that feels right:
     * the dragged chip drops after every chip whose centre the pointer has
     * already passed. A half-step bias here would flip the slot as soon as the
     * pointer merely touched the next chip's left edge, making the dock jump a
     * slot early on every drag to the right. Clamped to the last slot, so
     * dragging past the end still means "last", never one past it.
     */
    function slotForX(xInChips, count) {
        if (count <= 0)
            return -1;
        var step = root.chipW + root.chipSpacing * root.s;
        if (step <= 0)
            return 0;
        return Math.max(0, Math.min(count - 1, Math.round(xInChips / step)));
    }

    /** Pins-array index behind a run slot, or -1 when the slot is not laid out. */
    function pinIndexOfSlot(slot) {
        if (slot < 0)
            return -1;
        var seen = 0;
        var list = root.items || [];
        for (var i = 0; i < list.length; i++) {
            var c = list[i];
            if (!c || c.divider || c.pinIndex === undefined)
                continue;
            if (seen === slot)
                return c.pinIndex;
            seen += 1;
        }
        return -1;
    }

    /**
     * Arm a drag on a pinned chip. Nothing moves yet: the press is only
     * remembered, and the chip lifts once the pointer travels past the
     * threshold, so an ordinary click on a chip still launches/focuses instead
     * of being eaten as a no-op reorder.
     */
    function beginDrag(slot, mouse) {
        if (slot < 0)
            return;
        root.dragFrom = slot;
        root.dragTo = slot;
        root.dragMoved = false;
        root.dragPressX = mouse.x;
    }

    /**
     * Track the pointer, promoting the press to a drag once it has moved far
     * enough, then keep the drop slot following the pointer. `mouse` is in the
     * chip's own coordinates; mapping through the chip re-bases it into the row
     * without the caller having to know where the row sits.
     */
    function trackDrag(chipItem, mouse) {
        if (root.dragFrom < 0)
            return;
        if (!root.dragMoved && Math.abs(mouse.x - root.dragPressX) < root.dragThreshold)
            return;
        root.dragMoved = true;
        var p = chipItem.mapToItem(chips, mouse.x, 0);
        root.dragTo = root.slotForX(p.x, root.dragPinnedCount);
    }

    /**
     * Commit or discard the drag. The pins array is written only on a real
     * reorder, so a press that never moved cannot perturb the saved order.
     * `dragMoved` is deliberately left set: onClicked fires straight after
     * onReleased and reads it to swallow the click that ends a drag.
     */
    function endDrag() {
        if (root.dragFrom < 0)
            return;
        var fromSlot = root.dragFrom;
        var toSlot = root.dragTo;
        var moved = root.dragMoved;
        root.dragFrom = -1;
        root.dragTo = -1;
        if (moved && toSlot >= 0 && toSlot !== fromSlot) {
            var from = root.pinIndexOfSlot(fromSlot);
            var to = root.pinIndexOfSlot(toSlot);
            if (from >= 0 && to >= 0)
                DockPins.move(from, to);
        }
    }

    /**
     * Drop an in-flight drag whose chip no longer exists — its pin was unpinned
     * or its desktop entry vanished mid-press, so the delegate holding the
     * grab is gone and no release will ever arrive. Without this the bar would
     * keep a stale drop marker alive until the next press.
     */
    function abandonStaleDrag() {
        if (root.dragFrom >= 0 && root.dragFrom >= root.dragPinnedCount) {
            root.dragFrom = -1;
            root.dragTo = -1;
            root.dragMoved = false;
        }
    }

    /** Length of the leading run of pinned chips, i.e. the reorderable width.
     *  Counted from the freshly built `items` (not the pins array, which may
     *  be longer) and not via itemsModel.get(), which notifies nothing —
     *  `items` being reassigned on every rebuild is what re-evaluates this. */
    readonly property int dragPinnedCount: {
        var n = 0;
        var list = root.items || [];
        for (var i = 0; i < list.length; i++) {
            var c = list[i];
            if (c && !c.divider && c.pinIndex !== undefined)
                n += 1;
        }
        return n;
    }

    // ---- dock palette: the dock resolves its own effective theme, so the pane,
//      copy, hairline and the active/dot accents all come from ONE palette —
//      no global-Theme leaks. The selector mirrors the pill's theme choices
//      (light/dark/dynamic/manual), with the same split: manual renders locally
//      from the dock's own hue flags (PaletteHue), dynamic reads the shared
//      wallpaper palette (Dyn) — which only wallpaper changes ever rewrite — and
//      light/dark are static. The dock is themed independently of the pill, both
//      directions. The glass depth is a separate axis: "transparent" lets the
//      desktop glow through at glassAlpha, "solid" paints opaque. ----

/** Effective palette mode, resolved from the dock's own selector. */
    readonly property string dockMode: (Flags.dockTheme === "auto"
        || Flags.dockTheme === "transparent") ? "dark" : Flags.dockTheme
    readonly property bool dockEffDyn: root.dockMode === "dynamic"
    readonly property bool dockEffManual: root.dockMode === "manual"
    readonly property bool dockEffLight: root.dockMode === "light"
    /**
     * Local manual palette from the dock's OWN hue flags — the wallcolors.py
     * --hue math computed in QML. It never reads or writes the shared
     * colors.json, so the pill's dynamic palette (Dyn) does not move when the
     * dock's manual controls do. Always built, mode-independent, so a dockTheme
     * flip can never expose an empty object to the tokens below mid-update —
     * the dockEffManual guards decide when it is actually used.
     */
    readonly property var dockHue: PaletteHue.build(Flags.dockManualHue, Flags.dockManualSat, Flags.dockManualDark)
    /**
     * Translucency of the transparent pane, mirroring the pill's regular glass
     * (0.78 * pill opacity). The dock can not lean on the pill's readability
     * veil, so its floor sits a touch higher to keep icon and title contrast.
     */
    readonly property real glassAlpha: Math.max(0.45, Math.min(0.95, 0.78 * (Flags.pillOpacity || 1)))
    /** Legacy or "auto" flag values (pre-split saves) render as the transparent pane. */
    readonly property bool dockGlass: Flags.dockStyle !== "solid"

    /** The palette tokens below mirror Theme.qml's ternaries but resolve from
     *  the dock's own `dockMode` — so a forced dark dock keeps dark text and
     *  a vermilion dot even while the pill sits on a light palette, and the
     *  matched light/dynamic variants stay readable on their own grounds. */
    function blendColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property bool dockCustom: Flags.accentOverride.length > 0
    readonly property color dockAccent: root.dockCustom ? Flags.accentOverride : (root.dockEffManual ? root.dockHue.primary : (root.dockEffDyn ? Dyn.primary : "#ff9a64"))
    readonly property color dockActive: root.dockCustom ? Flags.accentOverride : (root.dockEffManual ? root.dockHue.primary : (root.dockEffDyn ? Dyn.primary : "#e0563b"))
    /** Text-colour override mirroring the pill's: a pinned hex recolours the dock's title copy too. */
    readonly property bool dockCustomText: Flags.textOverride.length > 0
    readonly property color dockCardTop: root.dockEffManual ? root.dockHue.surface_container_high
        : (root.dockEffDyn ? Dyn.surfaceContainerHigh
        : (root.dockEffLight ? "#f6f2ec" : "#171717"))
    readonly property color dockCardBot: root.dockEffManual ? root.dockHue.surface_container_low
        : (root.dockEffDyn ? Dyn.surfaceContainerLow
        : (root.dockEffLight ? "#ece6df" : "#0c0c0c"))
    readonly property color dockCream: root.dockCustomText ? Flags.textOverride
        : (root.dockEffManual ? root.dockHue.cream
        : (root.dockEffDyn ? Dyn.cream
        : (root.dockEffLight ? "#2a241f" : "#ececec")))
    /**
     * How much of the accent to blend into the pane.
     *
     * Only for the modes whose accent is drawn FROM their own palette — manual
     * and dynamic, where pane and accent are two tokens of one generated scheme
     * and the tint is what makes the bar look like it belongs to that palette.
     *
     * Zero for the static modes, which is what they need: light and dark are a
     * NEUTRAL ramp, and the accent there is the pill's fixed orange. Blending 5%
     * of #ff9a64 into the dark card's #171717 moved it to (35,29,26) — a warm
     * brown that reads as neither the pill's dark nor a tint of anything, which
     * is why a static dark dock looked brownish and stopped matching the pill.
     * Zero also makes static light/dark agree with `Theme.cardTop`/`cardBot`
     * exactly, which is the point of those two modes being static at all.
     */
    readonly property real dockPaneTint: (root.dockEffManual || root.dockEffDyn) ? 1 : 0
    readonly property color dockPaneTop: root.dockGlass
        ? Qt.alpha(root.blendColor(root.dockCardTop, root.dockAccent, 0.05 * root.dockPaneTint), root.glassAlpha)
        : root.blendColor(root.dockCardTop, root.dockAccent, 0.05 * root.dockPaneTint)
    readonly property color dockPaneBot: root.dockGlass
        ? Qt.alpha(root.blendColor(root.dockCardBot, root.dockAccent, 0.03 * root.dockPaneTint), root.glassAlpha)
        : root.blendColor(root.dockCardBot, root.dockAccent, 0.03 * root.dockPaneTint)
    readonly property color dockBorder: root.dockEffLight
        ? Qt.alpha("#000000", 0.12) : Qt.alpha("#ffffff", 0.14)
    readonly property color dockSheen: root.dockEffLight
        ? Qt.alpha("#ffffff", 0.22) : Qt.alpha("#ffffff", 0.07)
    readonly property color dockHighlight: root.dockEffLight
        ? Qt.alpha("#1c1a17", 0.08) : Qt.alpha("#ffffff", 0.12)
    readonly property color dockDotIdle: root.dockEffLight
        ? Qt.alpha("#2c2926", 0.72) : Qt.alpha("#e4e2e8", 0.72)
    readonly property color dockCopy: root.dockCustomText ? Flags.textOverride
        : (root.dockEffLight ? "#3b3833" : "#cfcdd4")
    readonly property color dockFaint: root.dockCustomText ? Qt.alpha(Flags.textOverride, 0.6)
        : (root.dockEffLight
        ? Qt.alpha("#3b3833", 0.6) : Qt.alpha("#cfcdd4", 0.55))
    readonly property color dockHair: Qt.alpha(root.dockCream, 0.08)
    readonly property color dockDim: Qt.rgba(0, 0, 0, 0.45)

    /**
     * The DOCK's settings palette, in the shape a settings surface's rows read.
     *
     * This is the whole point of handing the panel a palette object rather than
     * letting its rows reach for the pill's `Theme`: the dock's settings are
     * built from the dock's own tokens, resolved from the dock's own theme mode.
     * So a forced-light dock gets dark settings text, a manual dock's settings
     * are tinted by the dock's own hue, and changing the pill's theme — or the
     * pill's interface settings, margins or row seam — cannot reach any of it.
     */
    readonly property SettingsPalette dockPal: SettingsPalette {
        ink: root.dockCream
        sub: root.dockCopy
        faint: root.dockFaint
        dim: Qt.alpha(root.dockCopy, 0.75)
        tile: root.dockHighlight
        hair: root.dockHair
        edge: root.dockBorder
        accentInk: root.dockCream
        accent: root.dockAccent
        paneTop: root.dockPaneTop
        paneBot: root.dockPaneBot
    }

    property var pins: DockPins.pins
    property var items: []

    /**
     * True when the dock has nothing to show at all: no pinned apps, no
     * running apps, and no usage history to build a frequent-app shelf. The
     * shell window then retracts the bar as if it were suppressed (no reveal
     * strip either) and the reserve window releases its band via DockState.
     */
    readonly property bool empty: root.items.length === 0

    /** Launcher usage log (shared with surfaces/Launcher.qml), read for the
     *  empty-dock frequent-app shelf. Monitored through a FileView so external
     *  launches are picked up on the next poll. */
    readonly property string usageFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/launcher-usage.json"
    property var usage: ({})
    property string usageSig: ""

    FileView {
        id: usageStore
        path: root.usageFile
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    /** Re-parse the usage log only when its text actually changed, and return
     *  a signature fragment so an external launch flips the dock's item sig. */
    function usageSignature() {
        var raw = usageStore.text() || "";
        if (raw.length > 0 && raw !== root.usageSig) {
            root.usageSig = raw;
            try {
                root.usage = JSON.parse(raw);
            } catch (e) {
                root.usage = {};
            }
        }
        return root.usageSig;
    }

    /** The five most-launched apps, most-used first, tolerating missing
     *  entries and noDisplay rows (those would be dead chips). */
    function frequent() {
        var out = [];
        var keys = [];
        for (var fk in root.usage) {
            if (Object.prototype.hasOwnProperty.call(root.usage, fk)
                && root.usage[fk] > 0 && keys.indexOf(fk) < 0)
                keys.push(fk);
        }
        keys.sort(function(a, b) { return root.usage[b] - root.usage[a]; });
        for (var i = 0; i < keys.length && out.length < 5; i++) {
            var e = root.entryById(keys[i]);
            if (!e || e.noDisplay) continue;
            out.push({
                entry: e,
                cls: (e.id || "").toLowerCase(),
                name: e.name,
                pinned: false,
                suggested: true,
                windows: [],
                running: false,
                active: false
            });
        }
        return out;
    }

    /** Multi-window preview: one chip's hover popover. The shell window keeps
     *  its input band live while the bar is up, so no per-preview geometry
     *  needs reporting; previewOpen only gates the always-on-dock band. */
    property bool previewOpen: false

    width: slab.width
    height: dockH

    onHoveredChanged: {
        if (root.hovered) {
            revealTimer.stop();
            root.revealSession = true;
        } else {
            revealTimer.start();
        }
    }

    onSuppressedChanged: {
        /* The window's hover feed pauses while suppressed — it stays on only so
         * the open panel keeps a dismissal signal — so nothing may be left
         * latched when that happens. A `revealSession` still true at this point
         * keeps the bar out after the dock comes back, because auto-hide only
         * releases it on noticing the pointer leave, and by then there is no
         * feed left to notice with. */
        if (root.suppressed) {
            root.hovered = false;
            root.revealSession = false;
        }
    }

    /**
     * The one place that learns the pointer has left, and the one place the
     * settings panel closes because of it.
     *
     * The panel's click-away hangs off this timer deliberately, so the bar and
     * the panel cannot disagree: the bar cannot retract while its own panel is
     * open, and the panel cannot outlive the pointer by a different amount of
     * time than the bar does. It used to have an outline drawn just outside the
     * block, which was a second mechanism watching the same event, in the one
     * place where a second opinion is least welcome.
     *
     * The grace period is the reason to route through here at all. A pointer
     * crossing the block on its way to something behind it should not take the
     * panel with it on the way past, and 350ms is the delay the bar has always
     * applied to that same judgement.
     *
     * No open-time guard is needed, which is worth stating because one used to
     * be here. `openSettings` has a single call site — the gear's `onClicked` —
     * and the gear is inside `dockRegion`, which is in the input mask both
     * before and after the panel opens. So the pointer is on the bar when the
     * panel appears, `hovered` is already true, and this cannot fire on the
     * way in. That is a property of the geometry, so if a second way to open
     * the panel is ever added it has to be re-checked rather than assumed.
     */
    Timer {
        id: revealTimer
        interval: 350
        onTriggered: {
            if (root.hovered)
                return;
            root.revealSession = false;
            if (root.settingsOpen)
                root.closeSettings();
        }
    }

    Timer {
        id: itemsTimer
        // Poll is sig-guarded and nearly free when nothing changed, so it can
        // run fast: ~120ms means the active dot answers within a blink of the
        // activation actually landing (there is no reactive Hyprland event to
        // hook in this build). 400ms made the dot visibly lag after a click.
        // It is also the dock's only reason to keep asking what the session looks
        // like, so reclaim stops it rather than watching a bar nobody can see.
        interval: 120
        repeat: true
        running: Flags.dockEnabled && !root.reclaimed
        onTriggered: root.refreshItems()
    }

    /**
     * How long the bar may sit down before its chip delegates are dropped. Same
     * flag and same delay as the surface sweep in Pill.qml, so the whole shell
     * reclaims on one schedule behind one kill switch rather than growing a second
     * pair of its own.
     */
    Timer {
        id: reclaimTimer
        interval: Math.max(0, Flags.unloadSec) * 1000
        repeat: false
        onTriggered: root.dropContent()
    }

    Connections {
        target: DockPins
        function onPinsChanged() { root.refreshItems(); }
    }

    // Either of these can end a reclaim: the bar coming back up, or the flag that
    // asked for reclaiming in the first place being switched off.
    onDownChanged: root.updateReclaim()

    Connections {
        target: Flags
        // Turning memorySaver off hands the delegates straight back rather than
        // leaving them dropped until the bar next happens to come up.
        function onMemorySaverChanged() { root.updateReclaim(); }
    }

    Component.onCompleted: {
        root.refreshItems();
        // `down` is already true whenever the shell starts on a fullscreen
        // monitor or in a game mode, and onDownChanged does not fire for a value
        // set before this component existed, so the decision is made once here as
        // well.
        root.updateReclaim();
    }

    /**
     * Rebuild only when the underlying state actually changed. `items` stays
     * the live source of truth; `itemsModel` is a ListModel with flat, typed
     * roles that the chip Repeater binds to. When only live state flips (a
     * window becoming active, a tab opening) the rows are patched in place
     * with set()/move(): the chip delegates stay alive, so hover swell, loaded
     * icons, tooltips and any open preview are never dropped — which is what
     * used to read as a "shrink-and-bounce" a moment after clicking a chip.
     * Because rows update without recreating, the
     * active dot also answers immediately, even while the pointer is parked on
     * the dock. The model is rebuilt only when the chip set itself changes (an
     * app launched or quit, a pin toggled), which legitimately needs fresh
     * chips.
     */
    property string itemSig: ""
    property int modelRev: 0
    property var itemsModel: ListModel {}

    /**
     * The one place the reclaim decision is made, so the timer, the flag and the
     * two change handlers cannot disagree about who is responsible for what.
     * `down` and `memorySaver` are the whole policy; everything else follows.
     */
    function updateReclaim() {
        if (Flags.memorySaver && root.down) {
            // Already dropped: leave it dropped, and do not re-arm the timer for a
            // down period the delegates are already absent for.
            if (!root.reclaimed) reclaimTimer.start();
        } else {
            reclaimTimer.stop();
            if (root.reclaimed) root.restoreContent();
        }
    }

    /**
     * Drop the chip delegates. `itemSig` is invalidated first because it describes
     * delegates that are about to stop existing: leaving it in place would let the
     * first refresh after the bar returned match it, skip the rebuild, and leave
     * the dock permanently blank.
     */
    function dropContent() {
        if (root.reclaimed || !root.down) return;
        root.reclaimed = true;
        root.itemSig = root.droppedSig;
        root.itemsModel.clear();
        // Belt and braces. A drag cannot really outlive the bar going down, but
        // clearing the model out from under one would leave it holding a delegate
        // that is no longer there.
        root.abandonStaleDrag();
    }

    /**
     * Put the delegates back. This runs on the same change that starts the bar
     * returning, so the rebuild lands underneath the slide rather than after it.
     * It is cheap enough to be invisible: measured at 3ms for a two-chip dock
     * against a 420ms transition, and it reads the Hyprland and desktop-entry
     * state as cached bindings rather than re-querying, so what it costs is
     * object construction and nothing else.
     */
    function restoreContent() {
        if (!root.reclaimed) return;
        root.reclaimed = false;
        root.refreshItems();
    }

    function refreshItems() {
        // The delegates are dropped deliberately; rebuilding them behind the
        // reclaim's back would undo it, and the poll that drives this is the very
        // thing reclaim stops. `restoreContent` clears the flag before it gets
        // here, so it does reach the rebuild.
        if (root.reclaimed) return;
        var sig = root.itemsSignature();
        if (sig === root.itemSig) return;
        root.itemSig = sig;
        root.modelRev += 1;
        var next = root.buildItems();
        if (root.sameChipSet(root.items, next)) {
            root.syncModelOrder(next);
            // Patch only the rows that actually changed. Rewriting a row flips
            // its `rev`, which re-evaluates that delegate's bindings (icon
            // lookups, preview window sort) — rewriting every row on every
            // flip made all chips re-evaluate in the same frame the active
            // dot starts animating, stalling it. Untouched rows keep their
            // values (and rev), so the flip touches just the affected chips.
            var prevByKey = {};
            for (var p = 0; p < root.items.length; p++)
                prevByKey[root.chipIdent(root.items[p])] = root.winHash(root.items[p]);
            for (var j = 0; j < next.length; j++) {
                var cur = root.itemsModel.count > j ? root.itemsModel.get(j) : null;
                var k = root.chipIdent(next[j]);
                if (cur && root.sameRow(cur, next[j])
                        && prevByKey[k] !== undefined
                        && prevByKey[k] === root.winHash(next[j]))
                    continue;
                root.itemsModel.set(j, root.chipRow(next[j]));
            }
        } else {
            root.itemsModel.clear();
            for (var i = 0; i < next.length; i++)
                root.itemsModel.append(root.chipRow(next[i]));
        }
        root.items = next;
        root.abandonStaleDrag();
        DockState.empty = root.items.length === 0;
    }

    /** Whether a flattened model row still matches its freshly built chip:
     *  all live fields identical (windows are compared separately via
     *  winHash, since model rows don't carry them). */
    function sameRow(m, o) {
        var e = o.entry;
        return m.divider === !!o.divider
            && m.entryId === (e && e.id ? e.id : "")
            && m.icon === (e && e.icon ? e.icon : "")
            && m.cls === (o.cls || "")
            && m.name === (o.name || "")
            && m.pinned === !!o.pinned
            && m.suggested === !!o.suggested
            && m.running === !!o.running
            && m.active === !!o.active
            && m.ordSort === (o.ordSort || 0)
            && m.pinIndex === (o.pinIndex === undefined ? -1 : o.pinIndex);
    }

    /** Cheap fingerprint of a chip's window set (addresses + workspace +
     *  minimized), so preview reads know when a row genuinely changed even
     *  though its fields look identical. The divider carries no window list, so
     *  it hashes to "" — without that guard this threw on the divider and
     *  aborted the whole row-patch pass, leaving `items` stale whenever the
     *  chip set held still but live state changed. */
    function winHash(o) {
        var s = "";
        var ws = (o && o.windows) ? o.windows : [];
        for (var i = 0; i < ws.length; i++) {
            var w = ws[i];
            if (!w) continue;
            s += String(w.address || w.handle || "") + ":"
                + (w.workspace ? String(w.workspace.name) : "") + ":"
                + (w.minimized ? "m" : "-") + ";";
        }
        return s;
    }

    /** Stable chip identity for set/order bookkeeping: a divider, or the app's
     *  desktop-entry id (falling back to its window class) plus whether the
     *  chip is pinned. Accepts either a buildItems chip (carries `entry`) or a
     *  flattened ListModel row (carries `entryId`). Running/suggested/active
     *  are live state, not identity, so a suggested chip that launches into the
     *  running section keeps its delegate instead of being recreated. */
    function chipIdent(o) {
        if (!o) return "?";
        if (o.divider) return "|";
        var id = (o.entry && o.entry.id) ? o.entry.id : o.entryId;
        return (id ? "E:" + id : "C:" + (o.cls || "")) + (o.pinned ? ":P" : "");
    }

    /** True when two builds describe the same chips (same identities and
     *  count) regardless of order or live state — the signal to patch rows in
     *  place instead of recreating delegates. */
    function sameChipSet(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        var ids = {};
        for (var i = 0; i < a.length; i++) {
            var k = root.chipIdent(a[i]);
            ids[k] = (ids[k] || 0) + 1;
        }
        for (var j = 0; j < b.length; j++) {
            var k2 = root.chipIdent(b[j]);
            if (!ids[k2] || ids[k2] <= 0) return false;
            ids[k2] -= 1;
        }
        return true;
    }

    /** The flat, typed role object written to one ListModel row, mirroring a
     *  buildItems chip. Windows stay out of the model — this build's ListModel
     *  drops array roles on set() — so the preview re-reads them from `items`
     *  keyed off `rev` (which increments every applied pass).
     */
    function chipRow(o) {
        var e = o.entry;
        return {
            divider: !!o.divider,
            entryId: e && e.id ? e.id : "",
            icon: e && e.icon ? e.icon : "",
            cls: o.cls || "",
            name: o.name || "",
            pinned: !!o.pinned,
            suggested: !!o.suggested,
            running: !!o.running,
            active: !!o.active,
            ordSort: o.ordSort || 0,
            pinIndex: o.pinIndex === undefined ? -1 : o.pinIndex,
            rev: root.modelRev
        };
    }

    /** Reorder the list model rows to match the freshly built order (pins
     *  first, then running apps in session order) using positional moves,
     *  which shift existing delegates instead of recreating them. */
    function syncModelOrder(next) {
        for (var i = 0; i < root.itemsModel.count && i < next.length; i++) {
            if (root.chipIdent(root.itemsModel.get(i)) === root.chipIdent(next[i]))
                continue;
            for (var j = i + 1; j < root.itemsModel.count; j++) {
                if (root.chipIdent(root.itemsModel.get(j)) === root.chipIdent(next[i])) {
                    root.itemsModel.move(j, i, 1);
                    break;
                }
            }
        }
    }

    function itemsSignature() {
        var s = "";
        var tls = Hyprland.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i];
            if (t && t.workspace)
                s += root.classOf(t) + ":" + t.address
                    + (t.activated ? ":1" : ":0") + ";";
        }
        for (var j = 0; j < root.pins.length; j++)
            s += "P:" + root.pins[j] + ";";
        s += "U:" + root.usageSignature() + ";";
        return s;
    }

    /**
     * The one spelling of "which app is this?", used wherever the dock has to
     * decide whether a window and a pin are the same program.
     *
     * A window class and a desktop-entry id name one app three different ways,
     * and each of these is a real pairing on a real machine:
     *
     *   firefox              <-> firefox.desktop
     *   org.gnome.Nautilus   <-> org.gnome.nautilus.desktop   (case)
     *   Telegram             <-> org.telegram.desktop          (the ENTRY is
     *                                                             namespaced,
     *                                                             the class is
     *                                                             not)
     *
     * The last dotted segment, lowercased, with any .desktop suffix dropped, is
     * the same for all three. Comparing whole strings is not: it catches the
     * first and misses the other two, which is the whole failure.
     *
     * A fourth spelling needed handling too, and it is the one that bites hardest
     * because it is invisible in a desktop file: an Electron app reports its
     * BUILD CHANNEL in the window class. Hyprland sees `Warp-stable` where the
     * entry is `dev.warp.Warp.desktop`, and the two never match on any of the
     * above. The channel describes the build, not the app, so it is not part of
     * the app's identity and is dropped — but only from a known list, so
     * `code` and `code-insiders` stay the two different apps they are.
     *
     * It is deliberately coarse — two entries sharing a last segment would both
     * match a bare class — so it is only ever the SECOND attempt, after the
     * exact match, and it is asked identically on both sides of every
     * comparison. A rule that both sides apply the same way cannot make them
     * disagree, which is the property that was missing.
     */
    function appKey(s) {
        var q = String(s === undefined || s === null ? "" : s).toLowerCase();
        if (q.endsWith(".desktop"))
            q = q.slice(0, -8);
        var dot = q.lastIndexOf(".");
        var tail = dot >= 0 ? q.substring(dot + 1) : q;
        var dash = tail.lastIndexOf("-");
        if (dash > 0 && root.channelSuffixes.indexOf(tail.substring(dash + 1)) >= 0)
            tail = tail.substring(0, dash);
        return tail;
    }

    /** Build channels a window class may carry that an entry id never does. */
    readonly property var channelSuffixes: [
        "stable", "alpha", "beta", "dev", "nightly", "git", "next"
    ]

    /**
     * The apps this dock's pins actually RENDER, as `appKey`s.
     *
     * The RESOLVED pins, not `DockPins.pins`: a pin whose app has been
     * uninstalled still occupies a slot in the store but produces no chip, so
     * counting it here would let the pinned/running split believe a running app
     * was already pinned and silently drop it from the dock. An unresolvable
     * pin has to keep its chip in the running half, which is the only place it
     * can still be seen.
     */
    readonly property var pinnedAppKeys: {
        var out = [];
        for (var i = 0; i < root.pins.length; i++) {
            var e = root.entryById(root.pins[i]);
            if (e) out.push(root.appKey(e.id));
        }
        return out;
    }

    /**
     * Does a pin already own this app? THE question the pinned/running split
     * asks, as a name so the rule has exactly one definition.
     *
     * `id` may be a desktop-entry id or a raw window class — the whole point is
     * that both sides of that comparison are reduced by `appKey` before being
     * compared, because reducing them differently is precisely how one app came
     * to be emitted into both halves of the dock.
     */
    function isPinnedApp(id) {
        var k = root.appKey(id);
        if (!k) return false;
        return root.pinnedAppKeys.indexOf(k) >= 0;
    }

    /**
     * The window-class -> desktop-entry bridge: the exact match first (so a
     * class that IS an id never loses to a lookalike), then the tolerant key,
     * which is what lets a bare class find its namespaced entry.
     *
     * The old fallback needed a dot in the class before it would even try, and
     * compared only against the tail — so `Telegram` matched nothing at all and
     * the app lost both its icon and its identity.
     */
    function entryFor(cls) {
        if (!cls) return null;
        var apps = DesktopEntries.applications.values;
        var exact = Apps.byId(apps, cls);
        if (exact) return exact;
        var want = root.appKey(cls);
        if (!want) return null;
        for (var j = 0; j < apps.length; j++) {
            var e2 = apps[j];
            if (e2 && e2.id && root.appKey(e2.id) === want)
                return e2;
        }
        return null;
    }

    /**
     * Resolve a persisted pin by entry id, tolerating a .desktop suffix.
     *
     * The exact match is tried FIRST, and the suffix is only stripped as a
     * fallback: a desktop-entry id may legitimately end in the literal
     * ".desktop" (org.telegram.desktop, com.foo.desktop), and stripping
     * unconditionally rewrote those to "org.telegram" and matched nothing — so
     * the pin was saved, listed as pinned in the picker, and silently absent
     * from the dock.
     */
    function entryById(id) {
        if (!id) return null;
        var apps = DesktopEntries.applications.values;
        var exact = Apps.byId(apps, id);
        if (exact) return exact;
        var q = id.toLowerCase();
        if (!q.endsWith(".desktop")) return null;
        return Apps.byId(apps, q.slice(0, -8));
    }

    function classOf(t) {
        return (t && t.lastIpcObject && t.lastIpcObject.class) ? t.lastIpcObject.class
            : (t && t.wayland && t.wayland.appId) ? t.wayland.appId : "";
    }

    function anyActive(ws) {
        for (var i = 0; i < ws.length; i++)
            if (ws[i] && ws[i].activated) return true;
        return false;
    }

    function iconForName(name) {
        if (!name || name.length === 0) return "";
        if (name.charAt(0) === "/") return "file://" + name;
        if (Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name, "application-x-executable");
        return "";
    }

    function buildItems() {
        var out = [];
        var byClass = {};
        var order = [];
        var tls = Hyprland.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
            var t = tls[i];
            if (!t || !t.workspace) continue;
            var cls = root.classOf(t);
            if (!cls) continue;
            var key = cls.toLowerCase();
            if (!byClass[key]) { byClass[key] = []; order.push(key); }
            byClass[key].push(t);
        }

        // Resolve every live class to a desktop entry once, then group the
        // classes BY APP rather than by entry id.
        //
        // The grouping key is `appKey`, and that is the fix for a pinned app
        // showing up twice. This map is written from window classes and read
        // from pin ids, so a key the two sides spelled differently put one app
        // in both halves of the dock: the pin emitted a chip from its entry, the
        // window emitted another from its class, and neither half recognised
        // the other. Keying both ends by `appKey` makes the question identical
        // wherever it is asked.
        //
        // A class that resolves to no entry still gets a group, filed under its
        // own key — that is what lets an unresolvable class be recognised as a
        // pinned app instead of becoming a duplicate of it.
        var classEntry = {};
        var classesByApp = {};
        for (var o = 0; o < order.length; o++) {
            var k = order[o];
            var e = root.entryFor(k);
            classEntry[k] = e;
            var ak = root.appKey(e ? e.id : k);
            if (!ak) continue;
            if (!classesByApp[ak]) classesByApp[ak] = [];
            classesByApp[ak].push(k);
        }

        function windowsForApp(ak) {
            var keys = classesByApp[ak] || [];
            var acc = [];
            for (var n = 0; n < keys.length; n++)
                if (byClass[keys[n]]) acc = acc.concat(byClass[keys[n]]);
            return acc;
        }

        var pinnedKeys = [];
        for (var p = 0; p < root.pins.length; p++) {
            var pe = root.entryById(root.pins[p]);
            if (!pe) continue;
            var pk = (pe.id || "").toLowerCase();
            if (pinnedKeys.indexOf(pk) >= 0) continue;
            pinnedKeys.push(pk);
            // Its windows come from the app-keyed map, so a pinned app whose
            // window class is spelled differently from its entry id still reports
            // itself as running — which it did not before, so the pinned chip sat
            // there looking closed while a duplicate chip claimed it was open.
            var ws = windowsForApp(root.appKey(pe.id));
            out.push({
                entry: pe,
                cls: pk,
                name: pe.name,
                pinned: true,
                pinIndex: p,
                windows: ws,
                running: ws.length > 0,
                active: root.anyActive(ws)
            });
        }

        var running = [];
        for (var r = 0; r < order.length; r++) {
            var key = order[r];
            var e2 = classEntry[key];
            // Asked of the APP, before the entry is used for anything, and
            // whether or not it resolved: this is the line that keeps one app
            // out of the running half when a pin already owns it. Passing the
            // raw class when there is no entry is deliberate — an unresolvable
            // class is still a class the pin may own.
            if (root.isPinnedApp(e2 ? e2.id : key)) continue;
            var w = byClass[key];
            if (e2) {
                running.push({
                    entry: e2,
                    cls: key,
                    name: e2.name,
                    pinned: false,
                    windows: w,
                    running: true,
                    active: root.anyActive(w),
                    ordSort: DockState.ordinalOf(key),
                    idx: r
                });
            } else {
                var first = w[0];
                running.push({
                    entry: null,
                    cls: key,
                    name: (first && first.title) ? first.title : key,
                    pinned: false,
                    windows: w,
                    running: true,
                    active: root.anyActive(w),
                    ordSort: DockState.ordinalOf(key),
                    idx: r
                });
            }
        }

        // Running apps hold a STABLE session order: the sequence in which they
        // were first seen, kept by DockState for the life of the session. This
        // used to be sorted by lowest workspace, which made the whole shelf
        // reshuffle every time a window crossed a workspace — the dock now
        // reflects what you opened, not where the window happens to sit.
        running.sort(function(a, b) {
            if (a.ordSort !== b.ordSort) return a.ordSort - b.ordSort;
            return a.idx - b.idx;
        });

        if (out.length > 0 && running.length > 0)
            out.push({ divider: true });

        // Nothing pinned and nothing running: fall back to the most-launched
        // apps so the dock still has a shelf to offer (and teach pinning via
        // right-click). With no usage history this returns empty, which
        // retracts the bar — see `empty` / DockState.
        if (out.length === 0 && running.length === 0)
            return root.frequent();
        return out.concat(running);
    }

    /** Launch a closed app, or focus the best window of a running one. */
    function activate(item) {
        if (!item || item.divider) return;
        if (item.windows.length > 0) {
            root.focusApp(item);
        } else if (item.entry) {
            item.entry.execute();
        }
    }

    /**
     * Focus the app's most relevant window: one parked on this monitor's
     * active workspace wins, otherwise the first non-minimized window. Windows
     * in the special:minimized stash are skipped — those are exactly what the
     * minimize tray restores. Workspaces are compared by name, since a
     * toplevel's workspace object never carries a usable id here.
     */
    function focusApp(item) {
        var wsName = root.activeWsName();
        var best = null;
        var fallback = null;
        for (var i = 0; i < item.windows.length; i++) {
            var w = item.windows[i];
            if (!w || !w.workspace || w.workspace.name === "special:minimized") continue;
            if (!fallback) fallback = w;
            if (wsName && w.workspace.name === wsName) { best = w; break; }
        }
        var t = best || fallback;
        if (!t) return;
        root.focusAddress(t.address);
    }

    /**
     * Raise the window at `address` without moving the pointer. Hyprland's
     * focuswindow warps the cursor to the focused window's centre, so a dock
     * click would teleport the pointer away; toggling cursor:no_warps around
     * this single dispatch suppresses that warp only for this call. The toggle
     * is scoped here — no global config change, everything else keeps warping
     * as configured.
     */
    function focusAddress(addr) {
        if (addr.indexOf("0x") !== 0) addr = "0x" + addr;
        Quickshell.execDetached(["sh", "-c",
            "hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1; " +
            "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + addr + "\" })' >/dev/null 2>&1; " +
            "hyprctl eval 'hl.config({ cursor = { no_warps = false } })' >/dev/null 2>&1",
            "sh"]);
    }

    function activeWsName() {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName && ms[i].activeWorkspace
                && ms[i].activeWorkspace.name)
                return String(ms[i].activeWorkspace.name);
        return Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.name
            ? String(Hyprland.focusedWorkspace.name) : "";
    }

    /**
     * Windows for the hover preview, current-workspace first (mirrors
     * focusApp's preference). Minimized windows are skipped: those live in the
     * special:minimized stash and are restored from the tray instead.
     */
    function orderWindows(windows) {
        var wsName = root.activeWsName();
        var first = [];
        var second = [];
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i];
            if (!w || !w.workspace || w.workspace.name === "special:minimized") continue;
            if (wsName && w.workspace.name === wsName) first.push(w); else second.push(w);
        }
        return first.concat(second);
    }

    function togglePin(item) {
        if (!item || item.divider || !item.entry) return;
        DockPins.toggle(item.entry.id);
    }

    // ---- the bar ----

    Rectangle {
        id: slab
        radius: Math.min(20 * s, height / 2)
        // The gear sits at the right end, so the slab grows by its slot and the
        // app chips centre in what is left.
        width: chips.implicitWidth + gearSlot.width + 20 * s
        height: root.dockH
        anchors.horizontalCenter: parent.horizontalCenter
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.dockPaneTop }
            GradientStop { position: 1.0; color: root.dockPaneBot }
        }
        border.width: 1
        border.color: root.dockBorder
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.dockDim
            shadowBlur: 1.0
            shadowVerticalOffset: 8 * root.s
        }

        /** Glass top sheen: soft white falloff over the upper third. */
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.42
            radius: slab.radius - 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.dockSheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    /**
     * The app chips, centred in the slab minus the gear slot. Before the gear
     * existed they centred on the slab; centring them on the slab still would
     * shove every icon left by half the gear for no reason, so the wrap gives
     * them the space they actually have.
     */
    Item {
        id: chipsWrap
        anchors.left: parent.left
        anchors.right: gearSlot.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

    Row {
        id: chips
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.chipSpacing * root.s

        Repeater {
            model: root.itemsModel

            delegate: Item {
                id: chip
                required property var modelData
                required property int index
                readonly property bool divider: !!chip.modelData.divider
                readonly property bool hover: area.containsMouse || panel.containsMouse
                /** Pinned chips are the reorderable set; the divider and the
                 *  running shelf are not. */
                readonly property bool draggable: !chip.divider && chip.modelData.pinIndex >= 0
                readonly property bool lifted: root.dragActive && chip.draggable && chip.index === root.dragFrom
                /** The insertion caret sits between the origin and the target,
                 *  on whichever edge faces the origin, so it always reads as
                 *  "the gap you'll drop into". */
                readonly property bool dropBefore: root.dragActive && chip.draggable
                    && chip.index === root.dragTo && root.dragTo > root.dragFrom
                readonly property bool dropAfter: root.dragActive && chip.draggable
                    && chip.index === root.dragTo && root.dragTo < root.dragFrom
                width: chip.divider ? 6 * s : root.chipW
                height: root.dockH

                Rectangle {
                    visible: chip.divider
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 22 * s
                    color: Qt.alpha(root.dockHair, 0.7)
                }

                // Drop caret for the reorder in flight.
                Rectangle {
                    visible: chip.dropBefore || chip.dropAfter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: chip.dropBefore ? parent.left : undefined
                    anchors.right: chip.dropAfter ? parent.right : undefined
                    width: 2 * s
                    height: parent.height - 22 * s
                    radius: width / 2
                    color: root.dockActive
                }

                /**
                 * macOS-style hover: no backdrop box — the icon itself grows
                 * up out of its base (scale origin at the icon's bottom, so it
                 * enlarges toward the top of the dock like the real thing and
                 * never collides with the title/dot below). The resting icon
                 * is one size smaller than it used to be so the hover swell
                 * has room to grow proportionally bigger.
                 */
                Image {
                    id: chipIcon
                    visible: !chip.divider
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: (root.titled ? 9 : 12) * s
                    width: (root.titled ? 27 : 32) * s
                    height: (root.titled ? 27 : 32) * s
                    sourceSize.width: Math.round((root.titled ? 54 : 64) * s)
                    sourceSize.height: Math.round((root.titled ? 54 : 64) * s)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    transformOrigin: Item.Bottom
                    source: !chip.divider ? root.iconForName(
                        chip.modelData.icon ? chip.modelData.icon : chip.modelData.cls) : ""
                    opacity: !chip.modelData.running
                        && (chip.modelData.pinned || chip.modelData.suggested)
                        ? 0.55 : (chip.hover || chip.modelData.active) ? 1 : 0.9
                    /* Magnify up to but never past the dock's top edge: the
                     * icon base sits 36*s (titled) / 44*s (minimal) from the
                     * chip top, so a 1.27 / 1.32 scale still clears the
                     * hairline by ~1.5*s — it never looks like it escapes.
                     * A chip being dragged lifts on its own smaller swell, so
                     * it reads as picked up even with the pointer between
                     * chips and `hover` gone false. */
                    scale: chip.lifted ? (root.titled ? 1.16 : 1.2)
                        : chip.hover ? (root.titled ? 1.27 : 1.32) : 1
                    Behavior on scale { NumberAnimation { duration: Motion.fast } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Text {
                    visible: !chip.divider && root.titled
                    anchors.horizontalCenter: parent.horizontalCenter
                    /* Hangs off the icon's base, not the dock's floor. The title
                     * used to be bottom-anchored at 20*s, which put its top at
                     * ~35*s in a 68*s chip whose icon already ends at 36*s — so
                     * in full mode the first line of every label touched the
                     * icon. Measuring from the icon makes the gap explicit and
                     * independent of font metrics. */
                    anchors.top: chipIcon.bottom
                    anchors.topMargin: 4 * s
                    width: parent.width - 6 * s
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: 10 * s
                    font.weight: Font.DemiBold
                    color: root.dockCopy
                    opacity: chip.hover ? 1 : 0.85
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    /* Empty unless the label is actually on screen, for the same
                     * reason the preview rows gate theirs: a desktop entry's Name
                     * can carry CJK too, and shaping it for a label the minimal
                     * dock never shows would map the same 19.5 MiB of font. */
                    text: root.titled && !chip.divider ? (chip.modelData.name || "") : ""
                }

                Rectangle {
                    // Uniform indicator: same size for every running app, the
                    // active one distinguished purely by color. No size tween —
                    // an app switch used to make one dot swell while the other
                    // deflated (5.5s vs 4s), which read as growing/shrinking.
                    visible: !chip.divider && chip.modelData.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8 * s
                    width: 4 * s
                    height: 4 * s
                    radius: width / 2
                    color: chip.modelData.active ? root.dockActive : root.dockDotIdle
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    visible: !chip.divider
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    /* An open hand on the chips that can be dragged is the
                     * whole affordance — the dock never takes keyboard focus,
                     * so the cursor is the only upfront hint. */
                    cursorShape: chip.lifted ? Qt.ClosedHandCursor
                        : chip.draggable ? Qt.OpenHandCursor : Qt.PointingHandCursor
                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            root.beginDrag(chip.draggable ? chip.index : -1, mouse);
                    }
                    onPositionChanged: (mouse) => {
                        // The grab stays with this MouseArea for the whole press
                        // even as the pointer leaves the chip, so the drag
                        // tracks by run slot and never by hit-testing.
                        if (root.dragFrom === chip.index)
                            root.trackDrag(chip, mouse);
                    }
                    onReleased: (mouse) => {
                        // Any release on the grabbed chip ends the drag, not
                        // just a left one, so a second-button release cannot
                        // strand the drop caret. endDrag only commits when the
                        // press actually became a drag, so a right-click alone
                        // (which never arms one) still falls through to
                        // onClicked and pins/unpins as before.
                        if (root.dragFrom === chip.index)
                            root.endDrag();
                    }
                    onClicked: (mouse) => {
                        // A drag that ended here must not also launch or focus
                        // the chip; endDrag deliberately left dragMoved set for
                        // exactly this check, and it is consumed here.
                        if (root.dragMoved) {
                            root.dragMoved = false;
                            return;
                        }
                        if (mouse.button === Qt.RightButton)
                            root.togglePin(root.items[index]);
                        else
                            root.activate(root.items[index]);
                    }
                }

                Tooltip {
                    show: chip.hover && !preview.multi && !chip.divider
                    s: root.s
                    placement: "above"
                    title: chip.divider ? "" : chip.modelData.name
                }

                /**
                 * Multi-window hover preview: a small window picker above the
                 * chip, shown while the app has more than one window (terminal
                 * stacks, browser windows). Clicking a row raises that exact
                 * window with the pointer parked back on the dock. The shell
                 * window's input band stays live while the bar is up, so the
                 * popover takes clicks without any geometry hand-off.
                 */
                Item {
                    id: preview
                    readonly property var wins: (chip.modelData.rev >= 0) && root.items[index]
                        && root.items[index].windows
                        ? root.orderWindows(root.items[index].windows) : []
                    readonly property bool multi: !chip.divider && wins.length > 1
                    /**
                     * Whether the popover is on screen, named so the rows can gate
                     * their text on it. Binding a window title into a `Text` makes
                     * Qt shape it, and one CJK character in a title — a browser tab
                     * reading `浮島 Ukishima`, say — pulls Noto Sans CJK into the
                     * process: 19.5 MiB of font mapped for the life of the shell,
                     * paid by a popover nobody has hovered, on every chip, at
                     * startup. Gating the text on the same expression that decides
                     * visibility is what keeps the two from drifting apart again.
                     *
                     * The cost moves to the hover that earns it, which is the
                     * honest place for it: the font loads once, on the first hover
                     * that actually shows a title needing it, and stays loaded for
                     * the shell's lifetime after that.
                     */
                    readonly property bool shown: multi && !root.down && (chip.hover || panel.containsMouse)
                    readonly property real pW: 200 * s
                    readonly property real pH: Math.min(wins.length, 5) * (30 * s) + 14 * s
                    readonly property real gap: 9 * s
                    /**
                     * Stays open while the pointer is over the chip OR the panel
                     * itself. The panel mouse area covers the whole item — pane
                     * plus the gap strip below it — so the cursor can walk
                     * straight up out of the chip, across the floating gap and
                     * into the list without dropping the hover mid-way. Never
                     * shows while the dock is retracted (the bar slides the whole
                     * chip out of reach, so `hovered`/`revealSession` would clear
                     * on their own anyway; the !down guard is belt-and-braces
                     * against a stale hover during the slide).
                     */
                    visible: preview.shown
                    width: pW
                    height: multi ? pH + preview.gap : 0
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    z: 100

                    readonly property int winCount: Math.min(preview.wins.length, 5)
                    readonly property real rowH: 30 * s
                    readonly property real padT: 7 * s

                    /**
                     * Which row the pointer is over (drives the highlight);
                     * -1 when not over any row.
                     */
                    property int hoverIndex: -1

                    onVisibleChanged: {
                        root.previewOpen = preview.visible;
                    }

                    /** Window list pane, floating `gap` above the dock bar. */
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: preview.gap
                        radius: 12 * s
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.dockPaneTop }
                            GradientStop { position: 1.0; color: root.dockPaneBot }
                        }
                        border.width: 1
                        border.color: root.dockBorder
                        clip: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.dockDim
                            shadowBlur: 1.0
                            shadowVerticalOffset: 6 * root.s
                        }

                        /** Glass top sheen, matching the dock slab. */
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.4
                            radius: parent.radius - 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.dockSheen }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    /**
                     * Hover keeper + click target in one: sits on top of the
                     * rows so the panel stays open wherever the pointer rests
                     * on it, and resolves which row was clicked from mouseY.
                     * (Rows used to own their own MouseAreas, which stole the
                     * hover from the keeper and closed the panel mid-walk-up.)
                     */
                    MouseArea {
                        id: panel
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function rowIndex(y) {
                            var i = Math.floor((y - preview.padT) / preview.rowH);
                            if (i < 0 || i >= preview.winCount) return -1;
                            return i;
                        }

                        onPositionChanged: {
                            preview.hoverIndex = rowIndex(mouseY);
                        }
                        onExited: {
                            preview.hoverIndex = -1;
                        }
                        onClicked: {
                            var i = rowIndex(mouseY);
                            if (i < 0) return;
                            var win = preview.wins[i];
                            root.previewOpen = false;
                            root.focusAddress(win.address);
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: preview.padT
                        anchors.bottomMargin: preview.padT + preview.gap
                        spacing: 0

                        Repeater {
                            model: preview.wins.length > 5 ? preview.wins.slice(0, 5) : preview.wins

                            delegate: Item {
                                required property var modelData
                                required property int index
                                readonly property bool activeRow: modelData.activated
                                width: preview.width
                                height: preview.rowH

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6 * s
                                    anchors.rightMargin: 6 * s
                                    radius: 9 * s
                                    color: root.dockHighlight
                                    opacity: (preview.hoverIndex === index) ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9 * s
                                    anchors.right: metaRow.left
                                    anchors.rightMargin: 6 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: 11 * s
                                    color: root.dockCopy
                                    text: preview.shown
                                        ? (modelData.title ? modelData.title : "(untitled)") : ""
                                }

                                Row {
                                    id: metaRow
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8 * s
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5 * s

                                    Text {
                                        font.pixelSize: 9 * s
                                        color: root.dockFaint
                                        verticalAlignment: Text.AlignVCenter
                                        text: preview.shown && modelData.workspace
                                            && modelData.workspace.name
                                            ? String(modelData.workspace.name) : ""
                                    }

                                    Rectangle {
                                        visible: activeRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 5 * s
                                        height: 5 * s
                                        radius: width / 2
                                        color: root.dockActive
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }

    /**
     * The dock's settings trigger: a gear at the right end of the bar, behind a
     * divider so it plainly is not one of the app chips.
     *
     * It is a fixed slot rather than another entry in the chip row, on purpose.
     * The row's indices are run slots — the geometry the drag reorder is built
     * on — so a gear in the row would either be draggable or would shift every
     * slot after it. Out here it can never be pinned, unpinned, dragged,
     * launched, or counted in the pin order the picker shows.
     */
    Item {
        id: gearSlot
        anchors.right: parent.right
        anchors.rightMargin: 10 * s
        anchors.verticalCenter: parent.verticalCenter
        width: root.dockH
        height: root.dockH
        readonly property bool hover: gearArea.containsMouse

        /** Divider, so the gear reads as chrome rather than another app. */
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.left
            anchors.rightMargin: 5 * s
            width: 1
            height: 24 * s
            color: root.dockBorder
        }

        GlyphIcon {
            id: gearIcon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            /* Centred on the CHIPS' icon line, not on the slot. A chip's icon is
             * 27*s tall at 9*s from the top, so its centre is 22.5*s; the cog is
             * 19*s, which puts its top at 13*s. Centring it in the whole slot
             * instead would have floated it up near the top edge, and centring it
             * in the band above the caption would do the same — the caption sits
             * at 40*s, so that band is not the icon's band. */
            anchors.topMargin: root.titled
                ? 13 * s
                : (parent.height - 19 * s) / 2
            width: 19 * s
            height: 19 * s
            name: "cog"
            stroke: 1.8
            color: root.settingsOpen ? root.dockAccent
                : (gearSlot.hover ? root.dockCream : root.dockCopy)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        /**
         * The gear's caption, matching the app chips'. Hidden in minimal mode,
         * where every other chip is also captionless — a lone "Settings" under
         * the cog while the apps beside it have no names would look like the
         * dock's only pinnable item.
         */
        Text {
            visible: root.titled
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40 * s
            width: parent.width - 6 * s
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: 10 * s
            font.weight: Font.DemiBold
            color: root.settingsOpen ? root.dockAccent : root.dockCopy
            opacity: gearSlot.hover ? 1 : 0.85
            Behavior on opacity { ColorAnimation { duration: Motion.fast } }
            text: "Settings"
        }

        MouseArea {
            id: gearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleSettings()
        }

        Tooltip {
            show: gearSlot.hover
            s: root.s
            placement: "above"
            title: "Dock settings"
        }
    }

    /**
     * The gap between the slab's top edge and the panel's bottom edge, in this
     * item's own coordinates. The panel is a SIBLING of this bar in the shell
     * window, not a child, so it needs this to place itself: anchoring it to
     * the slab would anchor it to the slab's translated position too, and the
     * panel would leave with the bar whenever the dock slid down.
     */
    readonly property real panelGap: 10 * s
}
