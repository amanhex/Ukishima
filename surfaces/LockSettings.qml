pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 錠 LOCK sub-surface: how the session lock looks — which lock script runs,
 * the backdrop, blur and indicator toggles. The lock itself runs as a separate
 * process (lockscreen/) that cannot import ../Singletons, so its presentation
 * flags live in the shared flags.json and the lock reads them back on start.
 * Reached from the Appearance index and folds back to it on the back chevron
 * or an empty click.
 */
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    // ── Lock method ─────────────────────────────────────────────────────
    //
    // "hyprlock" is a hand-off to a program this project neither ships a
    // config for nor depends on, so it may not be installed at all. Offering
    // it unconditionally meant a machine without it had a setting that could
    // not be honoured — and scripts/lock.sh used to `exec hyprlock` on faith,
    // so choosing it there exited 127 and left the session unlocked.
    //
    // Probed with the same `command -v` the script uses, in the same shell, so
    // the row and the script can never disagree about what is available.

    /** True once the probe has run and hyprlock is on PATH. False before that
     *  and forever after if it is not there. */
    property bool hyprlockAvailable: false

    Process {
        id: hyprlockProbe
        running: true
        command: ["sh", "-c", "command -v hyprlock >/dev/null 2>&1"]
        onExited: (code) => root.hyprlockAvailable = (code === 0)
    }

    /**
     * The methods on offer, in order. Hyprlock is dropped when it is not
     * installed; Quickshell is always there, because the shell that is drawing
     * this row is itself Quickshell, so its own lock has no missing dependency.
     *
     * `vals` in the row registry below reads this same list, not a literal —
     * a seg row's keyboard cycling walks `vals`, so a hardcoded copy there
     * would let the arrow keys select a method the row no longer shows.
     */
    readonly property var methodValues: hyprlockAvailable
        ? ["hyprlock", "quickshell"]
        : ["quickshell"]

    /**
     * What the control shows, which is not always what the flag says. A flag
     * left on "hyprlock" from a machine that had it, or hand-edited into
     * flags.json, is not a value this row can display — SettingsSeg lights a
     * pill by comparing against `value`, so an unmatchable value lights
     * nothing and the row reads as broken. Show the method that will actually
     * run. The flag is deliberately left alone: lock.sh already downgrades,
     * and rewriting a setting just because someone opened a surface is a worse
     * surprise than a stale preference.
     */
    readonly property var methodValue:
        (methodValues.indexOf(Flags.lockMethod) >= 0) ? Flags.lockMethod : methodValues[0]

    /**
     * True when the Quickshell lockscreen is what will actually run, which is
     * the only case where the presentation settings below have anything to
     * configure. Keyed on `methodValue`, not `Flags.lockMethod`: a flag left on
     * "hyprlock" on a machine without hyprlock displays as quickshell and
     * lock.sh downgrades to it, so those settings are live and must be
     * reachable. Gating on the raw flag would hide settings that do work.
     */
    readonly property bool quickshellLock: methodValue === "quickshell"

    /**
     * Says why the option is missing, instead of silently showing one pill.
     *
     * It also names which lock is actually in charge, because everything below
     * the method row belongs to the Quickshell lock and disappears when hyprlock
     * is picked — and rows vanishing with no explanation read as broken rather
     * than inapplicable. The stored values are untouched and come straight back
     * on switching methods, so nothing has actually been lost.
     *
     * Kept short on purpose. avatarSub below carries the same warning: a sub
     * long enough to wrap takes the row from one line to two and moves every
     * row under it.
     */
    readonly property string methodSub: {
        if (!hyprlockAvailable)
            return "Quickshell lockscreen — hyprlock is not installed";
        if (!root.quickshellLock)
            return "Uses your hyprlock.conf";
        return "Uses the Quickshell lockscreen";
    }

    // ── Avatar path helpers ────────────────────────────────────────────
    //
    // The lock is a separate process and reads this flag verbatim, so what is
    // stored here has to survive being turned into a `file://` URL by a QML
    // Image over there. Two things that is sensitive to:

    readonly property string homeDir: Quickshell.env("HOME") || ""
    //* `~` and `~/x` are what a person actually types, and the placeholder
    //* used to advertise exactly that. A `file://` URL does not expand a
    //* leading tilde, though: the Image just sits at status=Null forever and
    //* the avatar silently never appears. Verified — `file://~/...` loads as
    //* status 0, the same path with $HOME substituted loads as status 1.
    //* Expand here so the flag is always an absolute path.
    function expandPath(p) {
        const t = (p === undefined || p === null) ? "" : String(p).trim();
        if (t === "")
            return "";
        if (t === "~")
            return homeDir;
        if (t.indexOf("~/") === 0)
            return homeDir + t.slice(1);
        return t;
    }

    //* The lock has no default avatar path — it used to be ~/.face, an i3lock
    //* convention that does not exist on most systems, so the default resolved
    //* to a blank grey circle. Empty means no image and the lock draws a
    //* person glyph. This is the resting hint in the field.
    readonly property string avatarPlaceholder: "no image"
    readonly property string avatarStored: expandPath(Flags.lockAvatarPath)
    //* Does the path we would actually use resolve to a real file? Checked
    //* with a FileView rather than assumed, so a typo shows up here instead of
    //* as a blank circle on the lock screen.
    //*
    //* `loaded` is the whole signal: true for a file that exists, false for
    //* one that does not. `loadFailed` is a *signal* here, not a property, so
    //* reading it yields a function object — which is truthy, and would have
    //* marked every path invalid. And text() is no use either: it is the
    //* file's contents, so a JPEG returns kilobytes of binary.
    readonly property bool avatarValid: avatarProbe.loaded
    //* Deliberately short. The field itself renders the path, so repeating it
    //* here just wrapped to two lines and crowded out the row. What the field
    //* cannot say is whether the path resolved and what an empty flag means.
    readonly property string avatarSub: {
        if (Flags.lockAvatarPath.trim() === "")
            return "unset, so the lock shows a person glyph";
        if (!avatarValid)
            return "no such file";
        return "";
    }

    FileView {
        id: avatarProbe
        //* No ?v= cache-busting here. That trick is for Image, which latches
        //* an Error on a missing file and will not re-read the same URL; this
        //* is a FileView, and a query string on a file:// URL makes it fail
        //* outright — verified: the same path loads with `loaded=true` plain
        //* and `loaded=false` with `?v=12345` appended, which reported a real
        //* wallpaper as "no such file".
        //*
        //* The path is a binding on avatarStored, and the flag only changes
        //* when the user commits an edit, so it re-arms on exactly the events
        //* that matter without needing to defeat any cache.
        path: root.avatarStored !== "" ? "file://" + root.avatarStored : ""
        printErrors: false
    }

    function commitAvatar(raw) {
        Flags.lockAvatarPath = expandPath(raw);
    }

    /**
     * Open or close the avatar field. One function for both the row's activate
     * (Return, or a click on the row body) and a click on the field at rest,
     * so the two entry points cannot drift.
     */
    function toggleAvatarEdit() {
        if (avatarPathRow.editing) {
            endAvatarEdit(false, "");
            return;
        }
        avatarPathRow.editing = true;
        //* Seeded from the flag, not from avatarStored, so an abandoned edit
        //* followed by a re-open shows what is actually stored.
        avatarInput.text = Flags.lockAvatarPath;
        //* callLater, not straight away: the field is still visible=false at
        //* this point in the turn, and focus on an invisible item is dropped.
        Qt.callLater(avatarInput.forceActiveFocus);
    }

    /**
     * Leave the avatar field, either committing what was typed or throwing it
     * away. Both paths only close the field — on abandon the flag was never
     * touched, so there is nothing to roll back, and on commit the new value
     * is already written. Drops focus explicitly, or the TextInput keeps the
     * key handler alive and the next Return lands in a field nobody is in.
     */
    function endAvatarEdit(commit, typed) {
        if (commit)
            commitAvatar(typed);
        avatarPathRow.editing = false;
        if (avatarInput.focus)
            avatarInput.focus = false;
    }

    // Turning the avatar off while the path field is open would otherwise leave
    // a focused TextInput inside a row that just vanished, holding the keyboard
    // hostage: the user is typing into something they cannot see. Abandon it —
    // the flag was never touched, so there is nothing to roll back, and the
    // next Return goes to the pill again.
    //
    // Switching to hyprlock does the same thing to that row as the toggle does,
    // by a different route, and it is the same failure: the field is focused,
    // the row is gone, and the keystrokes have nowhere to go. Handled here
    // rather than by watching `editing`, because `editing` is a local property
    // and nothing about closing the surface would ever set it.
    Connections {
        target: Flags
        function onLockShowAvatarChanged() {
            if (!Flags.lockShowAvatar && avatarPathRow.editing)
                root.endAvatarEdit(false, "");
        }
        function onLockMethodChanged() {
            if (!root.quickshellLock && avatarPathRow.editing)
                root.endAvatarEdit(false, "");
        }
    }

    /**
     * Every row this surface owns, in display order, hidden ones included.
     * `rows` below is the filtered view of this that the nav actually walks.
     */
    readonly property var allRows: [
        { item: methodRow, kind: "seg", vals: root.methodValues, get: function () { return Flags.lockMethod; }, set: function (v) { Flags.lockMethod = v; } },
        { item: bgRow, kind: "seg", vals: ["capture", "wallpaper", "solid"], get: function () { return Flags.lockBackground; }, set: function (v) { Flags.lockBackground = v; } },
        { item: blurRow, kind: "seg", vals: [0, 32, 64, 96], get: function () { return Flags.lockBlur; }, set: function (v) { Flags.lockBlur = v; } },
        { item: avatarRow, kind: "toggle", get: function () { return Flags.lockShowAvatar; }, set: function (v) { Flags.lockShowAvatar = v; } },
        //* kind "text" with get/set is inert: activateRow has no branch for it,
        //* so nothing opened the field. The wallpaper folder row passes an
        //* explicit activate instead, and that is the whole entry point.
        { item: avatarPathRow, kind: "text", activate: function () { root.toggleAvatarEdit(); } },
        { item: wifiRow, kind: "toggle", get: function () { return Flags.lockShowWifi; }, set: function (v) { Flags.lockShowWifi = v; } },
        { item: batteryRow, kind: "toggle", get: function () { return Flags.lockShowBattery; }, set: function (v) { Flags.lockShowBattery = v; } },
        { item: mediaRow, kind: "toggle", get: function () { return Flags.lockShowMedia; }, set: function (v) { Flags.lockShowMedia = v; } }
    ]

    /**
     * `allRows` minus rows that are not on screen.
     *
     * Hiding a row is not enough on its own. SettingsRows.kbMove steps kbIndex
     * through `rows` with no visibility test, so arrow keys walk straight onto a
     * hidden row and the focus ring vanishes into something nobody can see.
     * Measured: with the avatar off, idx=4 focused "Avatar image" while its
     * visible was false. Filtering here keeps one source of truth — the column,
     * which is what the eye reads — and hands the nav only what is reachable.
     *
     * `void root.quickshellLock` is load-bearing, not decoration. This is a
     * plain var rebuilt by iterating rows and reading each `item.visible`, and
     * the loop body never mentions lockMethod, so without that statement QML
     * has no dependency on the flag and the list is computed once and never
     * again. Switching to hyprlock would then hide five rows on screen while
     * the keyboard still walked them — the exact failure this filter exists to
     * prevent, reintroduced through the back door.
     */
    readonly property var visibleRows: {
        void Flags.lockShowAvatar;
        void root.quickshellLock;
        const out = [];
        for (const r of root.allRows) {
            if (r.item && r.item.visible !== false)
                out.push(r);
        }
        return out;
    }

    rows: root.visibleRows

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "錠"
            title: "LOCK"
            showBack: true
        }

        Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: methodRow
            surface: root
            name: "Lock method"
            icon: "lock"
            sub: root.methodSub

            SettingsSeg {
                s: root.s
                //* Built from methodValues so the pills and the row registry
                //* below are the same list, and neither can offer a method
                //* that is not installed.
                options: {
                    const out = [];
                    for (const v of root.methodValues) {
                        out.push({ label: v === "hyprlock" ? "Hyprlock" : "Quickshell", value: v });
                    }
                    return out;
                }
                value: root.methodValue
                onPicked: (v) => Flags.lockMethod = v
            }
        }

        SettingsRow {
            id: bgRow
            surface: root
            name: "Background"
            icon: "wallpaper"
            //* The backdrop is drawn by LockSurface, which only exists under the
            //* Quickshell lock. hyprlock paints whatever its own config says, so
            //* this setting is not merely ignored there — there is no code on
            //* that path that could read it.
            visible: root.quickshellLock

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Capture", value: "capture" },
                    { label: "Wallpaper", value: "wallpaper" },
                    { label: "Solid", value: "solid" }
                ]
                value: Flags.lockBackground
                onPicked: (v) => Flags.lockBackground = v
            }
        }

        SettingsRow {
            id: blurRow
            surface: root
            name: "Blur"
            icon: "droplet"
            sub: "Background blur strength"
            //* Hidden, not disabled, outside capture mode. LockSurface's blur
            //* layer is `visible: background === "capture" && ...`, so in
            //* wallpaper and solid there is genuinely nothing for this to
            //* change — a greyed-out row just spends a line on the reader.
            //*
            //* Hiding rather than disabling also closes a hole: a disabled row
            //* is still in `rows`, so kbActivate would keep seg-cycling a
            //* control the mouse refuses to touch. Out of the list means out
            //* of reach by both.
            //*
            //* The quickshellLock half is what keeps this from outliving
            //* bgRow: `lockBackground` keeps its stored value while the row is
            //* hidden, so gating on "capture" alone would leave a Blur row
            //* stranded under the method row with no Background above it once
            //* hyprlock is selected.
            //*
            //* The stored value is untouched, so switching back to capture
            //* finds the blur level you had rather than a default.
            visible: root.quickshellLock && Flags.lockBackground === "capture"

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Off", value: 0 },
                    { label: "Low", value: 32 },
                    { label: "Med", value: 64 },
                    { label: "High", value: 96 }
                ]
                value: Flags.lockBlur
                onPicked: (v) => Flags.lockBlur = v
            }
        }

        SettingsRow {
            id: avatarRow
            surface: root
            name: "Avatar"
            icon: "dot"
            //* LockSurface's, not hyprlock's. Same reasoning as bgRow.
            visible: root.quickshellLock

            LinkToggle {
                s: root.s
                on: Flags.lockShowAvatar
                onToggled: Flags.lockShowAvatar = !Flags.lockShowAvatar
            }
        }

        SettingsRow {
            id: avatarPathRow
            surface: root
            //* "Avatar image", not "Avatar": the row above already owns
            //* "Avatar", and two rows with the same label read as a rendering
            //* bug. This one is the image that toggle turns on.
            name: "Avatar image"
            //* "wallpaper" is the only one of image/wallpaper that exists in
            //* GlyphIcon's table; an unknown name silently falls through to the
            //* default shape, so "image" here would have drawn a different
            //* picture from the tile beside it.
            icon: "wallpaper"
            //* Pointless while the avatar is off — the lock draws nothing, so
            //* a path field here is editing a setting that has no effect.
            //* And pointless under hyprlock, which draws no avatar at all.
            visible: root.quickshellLock && Flags.lockShowAvatar
            //* While the field is open the caption clears, the way the
            //* wallpaper surface's header path does beside its own field:
            //* at rest it carries the one thing the field cannot say —
            //* whether the path resolved, and what an empty flag means.
            sub: avatarPathRow.editing ? "" : root.avatarSub
            captionOnFocus: true

            property bool editing: false

            //* Wallpaper-surface style field (see Wallpaper.qml folderRow):
            //* a bare TextInput, no box, opening instantly at full row width
            //* with the current value as its hint when cleared. 58* is where
            //* the name's text column ends — its 44* left offset plus its 14*
            //* gap — so the name elides to nothing as the field claims the
            //* space instead of sitting under it. No width animation: the
            //* swap is instant on the wallpaper surface too, and an animated
            //* close would re-wrap the caption mid-move.
            Item {
                width: avatarPathRow.editing ? avatarPathRow.width - 58 * root.s : 26 * root.s
                height: 26 * root.s

                TextInput {
                    id: avatarInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: avatarPathRow.editing
                    enabled: avatarPathRow.editing
                    clip: true
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    selectByMouse: true
                    selectionColor: Theme.verm

                    Keys.onPressed: (e) => {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            root.endAvatarEdit(true, text);
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Escape) {
                            root.endAvatarEdit(false, "");
                            e.accepted = true;
                        }
                    }

                    //* The stored path as the hint when the field is empty —
                    //* "no image" while the flag is unset, mirroring how the
                    //* wallpaper surface's field hints the dir it would use.
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: avatarInput.text.length === 0
                        text: root.avatarStored !== "" ? root.avatarStored : root.avatarPlaceholder
                        elide: Text.ElideMiddle
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }
                }

                //* "wallpaper", not "image" — that is the glyph the wallpaper
                //* folder row's tile uses, and the only one of the two that
                //* actually exists in GlyphIcon's table. An unknown name falls
                //* through to the default, so "image" would have rendered as a
                //* different shape than the one beside it.
                GlyphIcon {
                    anchors.centerIn: parent
                    visible: !avatarPathRow.editing
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "wallpaper"
                    color: avatarPathRow.focused ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
            }
        }

        SettingsRow {
            id: wifiRow
            surface: root
            name: "Wifi indicator"
            icon: "wifi"
            //* Drawn by LockSurface. hyprlock shows its own indicators from
            //* hyprlock.conf.
            visible: root.quickshellLock

            LinkToggle {
                s: root.s
                on: Flags.lockShowWifi
                onToggled: Flags.lockShowWifi = !Flags.lockShowWifi
            }
        }

        SettingsRow {
            id: batteryRow
            surface: root
            name: "Battery indicator"
            icon: "bolt"
            //* LockSurface's, same as wifiRow.
            visible: root.quickshellLock

            LinkToggle {
                s: root.s
                on: Flags.lockShowBattery
                onToggled: Flags.lockShowBattery = !Flags.lockShowBattery
            }
        }

        SettingsRow {
            id: mediaRow
            surface: root
            name: "Media player"
            icon: "music"
            //* LockSurface's card under the clock, same arrangement as wifiRow;
            //* hyprlock draws no media card of its own.
            visible: root.quickshellLock

            LinkToggle {
                s: root.s
                on: Flags.lockShowMedia
                onToggled: Flags.lockShowMedia = !Flags.lockShowMedia
            }
        }

    }
}
