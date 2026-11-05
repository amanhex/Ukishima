// Ukishima lockscreen — matches reference image:
// blurred desktop, date + big time top, avatar + bryly + pill bottom.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "designs"

Rectangle {
    id: root

    required property LockContext context
    // WlSessionLockSurface passed from shell.qml for per-screen screencopy
    required property var lockSurface
    readonly property string home: Quickshell.env("HOME")
    readonly property string userName: context.userName
    property string avatarPath: ""
    //* Absolute path to the avatar, or empty for none.
    //*
    //* There is deliberately no default. This used to fall back to ~/.face,
    //* an i3lock convention inherited from the lock PR: i3lock looks for that
    //* file, almost nothing else does, and it does not exist on most systems —
    //* so the default resolved to nothing and the avatar was a blank grey
    //* circle. An unset flag now means no image, and the row draws a person
    //* glyph instead.
    //*
    //* A `file://` URL does not expand a leading tilde, so `~/Pictures/me.png`
    //* loads as status=Null and the avatar silently never appears. The
    //* settings surface expands before storing, but flags.json is a plain
    //* file anyone can edit by hand, so expand here too.
    readonly property string facePath: {
        const t = avatarPath.trim();
        if (t === "")
            return "";
        if (t === "~")
            return home;
        if (t.indexOf("~/") === 0)
            return home + t.slice(1);
        return t;
    }
    //* Is there an image to show at all? Both "no path" and "path that will
    //* not load" want the glyph, so the two are asked apart once here instead
    //* of the Image and the Label each re-deriving it.
    readonly property bool avatarWanted: facePath.length > 0
    // grim pre-capture from lock.sh (hyprlock screenshot equivalent),
    // then live ukishima wallpaper, then static fallback
    // .jpg because lock.sh captures with `grim -t jpeg`; see the note there.
    readonly property string lockShot: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima/lock-shot.jpg"
    readonly property string stateWallpaper: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/ukishima/wallpaper"
    readonly property string wallpaperFallback: home + "/Pictures/Wallpapers/current_wallpaper.jpg"
    //* The wallpaper the shell is actually showing, read from the same state
    //* file wallpaper.sh writes (ukishima/wallpaper holds the current
    //* wallpaper's path, one line). The lockscreen runs as its own process and
    //* cannot import Singletons, so it re-reads the file itself. Falls back to
    //* the legacy current_wallpaper.jpg only when that state file is missing.
    property string currentWallpaper: ""
    readonly property string wallpaperSource: currentWallpaper.length > 0 ? currentWallpaper : wallpaperFallback
    //* The wallpaper the shell stores may be a video, which no Image can paint;
    //* the backdrop resolution below (videoBackdropCandidates) handles that.
    readonly property bool wallpaperIsVideo: /\.(mp4|webm|mkv|mov)$/i.test(wallpaperSource)

    //* wallpaper.sh already extracts a still frame of a video wallpaper:
    //* palette_update() runs on every wallpaper change and, for a video, writes
    //* make_still()'s first frame to ukishima/wallpapers/wallpaper-still.png
    //* (per-output variants are wallpaper-still-<output>.png, written by
    //* apply_visual for a per-output set). That still is a clean, decodable
    //* picture of the wallpaper itself, so the "wallpaper" backdrop must prefer
    //* it over lock.sh's grim capture. The capture is the whole desktop — every
    //* open window included — so using it made "wallpaper" look identical to
    //* "capture" whenever the wallpaper was a video, and a failed capture fell
    //* through to the base colour. The capture stays only as a last resort.
    readonly property string wallpaperCache: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima/wallpapers"
    readonly property string screenName: lockSurface && lockSurface.screen ? lockSurface.screen.name : ""
    //* Ordered backdrops to try for a video wallpaper: the shared still, this
    //* output's still, then the grim capture. wallpaperShot walks the list on
    //* Image.Error, so a missing still degrades instead of showing black. For a
    //* still image the list is just the one wallpaper file.
    readonly property var videoBackdropCandidates: {
        if (!wallpaperIsVideo)
            return ["file://" + wallpaperSource];
        var base = wallpaperCache + "/wallpaper-still";
        var list = ["file://" + base + ".png"];
        if (screenName.length > 0)
            list.push("file://" + base + "-" + screenName + ".png");
        list.push("file://" + lockShot);
        return list;
    }

    //* lock.sh redirects the lock's stderr into its own log
    //* (${XDG_STATE_HOME:-$HOME/.local/state}/ukishima/lock.log), so one
    //* console.log per lock says exactly which file the backdrop resolved to and
    //* whether it came from the state file or the legacy fallback. Without it,
    //* "the lock shows the wrong wallpaper" is unanswerable from outside the
    //* session.
    function reportWallpaper(how) {
        console.log("[lock] wallpaper " + how + ": mode=" + background
            + " state=" + stateWallpaper
            + " current=" + (currentWallpaper || "<empty>")
            + " using=" + (wallpaperIsVideo ? root.videoBackdropCandidates[0] + " (video still)" : wallpaperSource)
            + " fallbackUsed=" + (currentWallpaper.length === 0));
        root.reportCapture(how);
    }

    //* Which backdrop layer actually ended up painting, and why. "capture"
    //* looks identical to "solid" whenever the screenshot is missing or fails
    //* to load, and the mode string in the log above cannot tell those two
    //* cases apart — it only reports what was *asked for*. This reports what
    //* was *drawn*, which is the only thing that distinguishes a working
    //* capture from a silently skipped one.
    function reportCapture(why) {
        if (background !== "capture")
            return;
        let layer;
        if (grimShot.status === Image.Ready)
            layer = "grim screenshot " + lockShot + " (loaded, blur=" + blurMax + ")";
        else if (bgShot.hasContent)
            layer = "live screencopy blur=" + blurMax;
        else if (grimSource === "")
            layer = "no capture file — showing wallpaper " + wallpaperSource;
        else
            layer = "NO CAPTURE (" + lockShot + " status=" + grimShot.status + ") — showing wallpaper " + wallpaperSource;
        if (root.captureLogged)
            return;
        root.captureLogged = true;
        console.log("[lock] capture " + why + ": " + layer);
    }

    property bool captureLogged: false

    readonly property bool fieldInError: context.showFailure
    //* Clock format follows the desktop General setting (DisplaySurface timeRow
    //* -> Flags.time12h), and the lock battery shimmer follows the Battery
    //* surface toggle (Flags.batteryShimmer && !reduceMotion). Read-only: the
    //* lockscreen runs as a separate process that cannot import ../Singletons,
    //* and a partial JsonAdapter must never write back to the shared
    //* flags.json (writeAdapter would clobber every other key) — so this only
    //* parses the file and never writes it.
    property bool use12h: false
    property bool batteryShimmerOn: true
    //* Read from the desktop's reduceMotion setting. The lock composes its
    //* final state before the first frame; this snaps the staged entrance to
    //* its end state and turns the battery shimmer and other incidental motion
    //* off. The unlock handover stays, because fading the furniture is what
    //* keeps the compositor from flashing.
    property bool reduceMotion: false
    //* Lock-specific settings, written by the pill's LOCK surface (surfaces/
    //* LockSettings.qml -> Flags -> flags.json) and read back here. Defaults
    //* match the Flags adapter so a missing or partial file keeps today's look.
    property bool showAvatar: true
    property bool showWifi: true
    property bool showBattery: true
    property bool showMedia: true
    property int blurMax: 64
    //* "capture" grim-captures the desktop at lock time, "wallpaper" uses the
    //* live wallpaper, "solid" paints the opaque backdrop colour.
    property string background: "capture"
    //* Lock layout, chosen on the pill's SURFACE STYLES page. "default" is the
    //* original furniture below; every other value loads a design from
    //* lockscreen/designs/ over the same backdrop, auth and flag handling.
    property string styleLock: "default"

    //* The designs carry far more small mono type, thin rules and glyph tiles
    //* than the default furniture (one huge clock and a pill). Over a sharp
    //* desktop capture — blur Off or Low — that fine detail disappears into
    //* whatever is behind it, which the default lock's 92px clock never did.
    //* So while a design is up in capture mode the shared veil strengthens as
    //* the blur weakens, and legibility stops depending on the user picking a
    //* heavy blur. Zero for the default lock and for wallpaper/solid, and it
    //* rides `held` on the way out so the unlock handover does not dark-flash.
    readonly property real designVeil: {
        if (styleLock === "default" || background !== "capture")
            return 0;
        return 0.34 * Math.max(0, Math.min(1, (48 - blurMax) / 48));
    }

    //* Bound directly to the capture lock.sh took BEFORE this process was
    //* spawned, so the file is already complete and decodable by the time the
    //* first frame is mapped. This replaces a poll that re-read the file every
    //* 25ms with a fresh ?v= cache-buster until it decoded -- 13 attempts and
    //* ~300ms in practice, because each retry landed on grim's half-written
    //* PNG and latched status=Error. Nothing here needs retrying any more.
    //*
    //* No existence pre-check: Quickshell's FileView has no `exists` function
    //* in any released version (verified against the 0.2.x/0.3.x docs), so
    //* guarding the URL with one would throw and leave the capture permanently
    //* unbound. A missing file is not a special case to predict anyway -- bind
    //* the URL and let the Image report status=Error, which the wallpaper
    //* layer behind already treats as "no capture".
    //* The pre-capture is always decoded, even in wallpaper mode. It is the
    //* exact desktop pixels at lock time, so the entrance fade can start from
    //* the thing that is already on screen and settle to the composed lock.
    //* Without it the first lock frame showed the chosen wallpaper (which may
    //* not match the live desktop crop) and then the style faded in, which
    //* reads as two steps rather than one transition.
    readonly property string grimSource: "file://" + lockShot

    //* Re-report if the mode changes after load, so a lock that starts in the
    //* default and is then pointed at "capture" still says what it painted.
    onBackgroundChanged: {
        root.captureLogged = false;
        root.reportCapture("mode=" + background);
        root.evaluateBackdrop();
        root.maybeCompose();
    }

    onStyleLockChanged: {
        root.evaluateDesign();
        root.maybeCompose();
    }

    //* Read the wallpaper state now instead of waiting for its onLoaded
    //* signal. blockLoading has the file text ready at component completion;
    //* onLoaded fires afterwards, by which time the surface has already
    //* painted the legacy fallback (which usually does not exist). Reading it
    //* here keeps the first frame on the real wallpaper.
    function syncWallpaperState() {
        try {
            const p = wallpaperState.text().trim();
            if (p.length > 0) {
                root.currentWallpaper = p;
                root.wallpaperReady = true;
            }
        } catch (e) {
        }
    }

    function syncSharedFlags() {
        try {
            var shared = JSON.parse(sharedFlags.text());
            if (shared && typeof shared.time12h === "boolean")
                root.use12h = shared.time12h;

            root.batteryShimmerOn = (!shared || shared.batteryShimmer !== false) && (!shared || shared.reduceMotion !== true);

            if (shared && typeof shared.reduceMotion === "boolean")
                root.reduceMotion = shared.reduceMotion;

            if (shared && typeof shared.lockShowAvatar === "boolean")
                root.showAvatar = shared.lockShowAvatar;

            if (shared && typeof shared.lockShowWifi === "boolean")
                root.showWifi = shared.lockShowWifi;

            if (shared && typeof shared.lockShowBattery === "boolean")
                root.showBattery = shared.lockShowBattery;

            if (shared && typeof shared.lockShowMedia === "boolean")
                root.showMedia = shared.lockShowMedia;

            if (shared && typeof shared.lockBlur === "number")
                root.blurMax = shared.lockBlur;

            if (shared && typeof shared.lockAvatarPath === "string")
                root.avatarPath = shared.lockAvatarPath;

            if (shared && ["capture", "wallpaper", "solid"].indexOf(shared.lockBackground) >= 0)
                root.background = shared.lockBackground;

            if (shared && ["default", "relay", "folio", "editorial", "phase", "spine", "reactive"].indexOf(shared.styleLock) >= 0)
                root.styleLock = shared.styleLock;
            return true;
        } catch (e) {
            return false;
        }
    }

    FileView {
        id: sharedFlags

        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            root.flagsReady = true;
            root.syncSharedFlags();
            root.evaluateDesign();
            root.evaluateBackdrop();
            root.maybeCompose();
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.flagsReady = true;
            root.use12h = false;
            root.batteryShimmerOn = true;
            root.showAvatar = true;
            root.showWifi = true;
            root.showBattery = true;
            root.showMedia = true;
            root.blurMax = 64;
            root.background = "capture";
            root.avatarPath = "";
            root.styleLock = "default";
            root.evaluateDesign();
            root.evaluateBackdrop();
            root.maybeCompose();
        }
    }

    FileView {
        id: wallpaperState

        path: root.stateWallpaper
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            // text() is a *call* in this Quickshell build. `text.trim()` grabs
            // the native function object and throws
            // "Property 'trim' of object function text() ... is not a function",
            // which left currentWallpaper empty and silently fell back to the
            // legacy path. Matches sharedFlags.text() above, which works.
            root.currentWallpaper = text().trim();
            if (wallpaperShot)
                wallpaperShot.candidate = 0;
            root.wallpaperReady = true;
            root.reportWallpaper("loaded");
            root.evaluateBackdrop();
            root.maybeCompose();
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.currentWallpaper = "";
            if (wallpaperShot)
                wallpaperShot.candidate = 0;
            root.wallpaperReady = true;
            root.reportWallpaper("load-failed");
            root.evaluateBackdrop();
            root.maybeCompose();
        }
    }

    color: "#0b0d0c"
    focus: true
    //* Password capture goes through the raw keymap, not through a
    //* TextField. The dots are the entire UI, so all that is needed is
    //* "append printable characters, delete on backspace" -- and the
    //* invisible-TextField version of that routed every keystroke through
    //* the compositor's text-input protocol. Inside a WlSessionLock on
    //* Hyprland that path drops characters: an 11-character password
    //* reached PAM as 3, and was rejected as wrong.
    //*
    //* Key events reach the focused item through the ordinary keymap, which
    //* never touches text-input at all. It is also the better fit for a
    //* lock: no caret to blink, no selection, and nothing for a clipboard
    //* or a screenshot to catch.
    Keys.onPressed: (event) => {
        // never eat keystrokes mid-authentication
        if (context.unlockInProgress)
            return ;
        if (event.key === Qt.Key_Escape) {
            context.currentText = "";
            event.accepted = true;
            return ;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            context.tryUnlock();
            event.accepted = true;
            return ;
        }
        if (event.key === Qt.Key_Backspace) {
            context.currentText = context.currentText.slice(0, -1);
            event.accepted = true;
            return ;
        }
        // Space arrives as Qt.Key_Space with an empty event.text on some
        // keymaps, so it has to be special-cased before the text test below.
        if (event.key === Qt.Key_Space) {
            context.currentText += " ";
            event.accepted = true;
            return ;
        }
        // Only reject the modifiers that mean "this is a shortcut, not
        // text". Shift and CapsLock MUST be allowed through: they are how
        // capitals, "!", "?", "@" and every other shifted symbol are typed,
        // and the resulting character has already been resolved into
        // event.text by the keymap. Rejecting them here made any password
        // containing an uppercase letter or a symbol impossible to enter.
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return ;
        // Reject C0/C1 control characters, which can reach us as text on
        // odd keymaps and would end up inside the PAM response. Anything
        // else printable is fair game, including multi-codepoint graphemes
        // from non-Latin layouts (Devanagari, Hangul, emoji) where a single
        // key press is legitimately more than one UTF-16 unit.
        const t = event.text;
        if (t && t.length > 0) {
            let clean = true;
            for (let i = 0; i < t.length; i++) {
                const c = t.charCodeAt(i);
                if ((c < 0x20 && c !== 0x09) || (c >= 0x7f && c <= 0x9f)) {
                    clean = false;
                    break;
                }
            }
            if (clean) {
                context.currentText += t;
                event.accepted = true;
            }
        }
    }
    // ── Releasing the lock ──
    //
    //* The unlock used to fade the whole surface to opacity 0, which revealed
    //* the WlSessionLockSurface's own #0b0d0c — a 40ms hold of solid black
    //* between the end of the fade and the lock actually dropping, visible as a
    //* black flash on every unlock. Nothing fades to nothing now. The lock
    //* *becomes* the desktop: the furniture leaves, and the blur relaxes until
    //* the picture is the desktop, so the compositor's handover lands on a
    //* frame that is already what is behind it.
    //
    //* One value drives the whole release so its parts cannot drift apart.
    readonly property bool closing: context.closing
    property real release: 0
    readonly property int releaseMs: 200

    onClosingChanged: {
        if (closing)
            releaseAnim.start();
    }

    NumberAnimation {
        id: releaseAnim

        target: root
        property: "release"
        from: 0
        to: 1
        //* Deliberately LINEAR. The easing that makes this look smooth lives in
        //* blurAt(), because the quantity that has to be paced evenly is the
        //* perceived blur, not the blurMax number.
        duration: root.reduceMotion ? 0 : root.releaseMs
        easing.type: Easing.Linear
    }

    //* ── Atomic compose ──
    //
    //* The lock surface is the first frame the compositor gives us, but the
    //* surface and its contents do not all become paintable on the same frame
    //* if they are left to load asynchronously: the backdrop image is decoded
    //* immediately, then the capture/veil/design are laid out and their text
    //* rasterised a frame or two later. Left alone that reads as wallpaper ->
    //* dim -> style, three separate arrivals under the entrance.
    //*
    //* The normal path below reads flags and the wallpaper path synchronously
    //* in Component.onCompleted, so the first painted frame already has the
    //* right background, veil and design, and the staged entrance starts from
    //* that complete scene. This gate is the fallback for a decode that is
    //* genuinely still in flight: until everything settles the backdrop stays
    //* a plain, undimmed copy of what is already on screen, then `composed`
    //* flips once and the entrance runs on the settled scene.
    property bool composed: false
    property bool flagsReady: false
    property bool wallpaperReady: false
    property bool backdropReady: false
    property bool designReady: false

    function evaluateBackdrop() {
        if (root.background === "solid") {
            root.backdropReady = true;
            return;
        }
        if (root.background === "wallpaper") {
            root.backdropReady = wallpaperShot.status === Image.Ready
                || wallpaperShot.status === Image.Error;
            return;
        }
        root.backdropReady = grimShot.status === Image.Ready
            || grimShot.status === Image.Error
            || bgShot.hasContent;
    }

    function evaluateDesign() {
        if (root.styleLock === "default") {
            root.designReady = true;
            return;
        }
        root.designReady = designLoader.status === Loader.Ready
            || designLoader.status === Loader.Error;
    }

    function maybeCompose() {
        if (root.composed)
            return;
        if (root.flagsReady && root.wallpaperReady
            && root.backdropReady && root.designReady)
            settleTimer.start();
    }

    //* Two frames of grace after the Loader reports Ready. The design is
    //* instantiated and laid out by then; this only lets its text nodes reach
    //* the scene graph so the first visible frame is already complete.
    Timer {
        id: settleTimer

        interval: 32
        repeat: false
        onTriggered: root.composed = true
    }

    //* An invisible lock is worse than a staged one. If flags, the backdrop or
    //* a design never settle (a broken file, a compositor that never fills the
    //* screencopy), show the lock anyway rather than leaving the furniture at
    //* zero opacity forever.
    Timer {
        running: true
        interval: 1200
        repeat: false
        onTriggered: root.composed = true
    }

    //* Entrance choreography, one master clock. The backdrop and veil are
    //* already final on the first frame; only the furniture is staged, with
    //* each element mapped to its own window by stage(). This mirrors the
    //* default lock's clock-drifts-in / auth-rises entrance and gives every
    //* surface style the same kind of assembly instead of a uniform fade.
    property real entrance: 0
    readonly property int entranceMs: 380

    function stage(from, to, peak) {
        const u = Math.max(0, Math.min(1, (root.entrance - from) / (to - from)));
        return (1 - Math.pow(1 - u, 3)) * peak;
    }

    onComposedChanged: {
        if (composed)
            startEntrance();
    }

    property bool entranceStarted: false

    function startEntrance() {
        if (entranceStarted)
            return;
        entranceStarted = true;
        if (reduceMotion) {
            entrance = 1;
            return;
        }
        showAnim.start();
    }

    NumberAnimation {
        id: showAnim

        target: root
        property: "entrance"
        from: 0
        to: 1
        duration: root.entranceMs
        //* Linear: stage() applies the easing per element window, so each
        //* stage keeps its own curve instead of being flattened into one.
        easing.type: Easing.Linear
    }

    //* Unlock only. Entrance opacity lives on the furniture via stage(), so
    //* the two phases cannot fight over the same property.
    readonly property real held: 1 - Math.max(0, Math.min(1, root.release))

    //* Backdrop-side treatment (dim, veil, vignette, grading). It follows
    //* `held` on unlock but stays off until the scene is composed, so the
    //* deferred-decode path still starts from the plain desktop and then
    //* settles in one step instead of dimming an empty backdrop.
    readonly property real backdropHeld: root.composed ? root.held : 0

    //* Perceived blur is very non-linear in blurMax. Measured on a real
    //* 1920x1200 capture, recording the share of high-frequency detail that
    //* survives each value:
    //*
    //*     blurMax  64    48    32    24    16    12     8     4     2     0
    //*     detail  .19   .22   .30   .37   .50   .57   .67   .80   .87  1.00
    //*
    //* Ramping blurMax linearly spends the first ~120ms of a 200ms release in
    //* the flat top where .19 -> .30, i.e. where nothing visibly happens, and
    //* then snaps from .30 to sharp in the last 80ms. So the release drives the
    //* *perceived* progress and blurAt() inverts this measurement to get the
    //* blurMax that produces it, which paces what the eye actually sees.
    function blurAt(p) {
        const t = Math.max(0, Math.min(1, p));
        const b = root.blurMax;
        //* p -> blurMax, sampled from the table above.
        const steps = [ [0.0, 1.0], [0.04, 0.75], [0.14, 0.50], [0.22, 0.375],
            [0.38, 0.25], [0.47, 0.1875], [0.59, 0.125], [0.75, 0.0625],
            [0.84, 0.03125], [1.0, 0.0] ];
        if (t <= steps[0][0])
            return b * steps[0][1];
        for (let i = 1; i < steps.length; ++i) {
            if (t <= steps[i][0]) {
                const lo = steps[i - 1];
                const hi = steps[i];
                const f = (t - lo[0]) / (hi[0] - lo[0]);
                return b * (lo[1] + f * (hi[1] - lo[1]));
            }
        }
        return 0;
    }

    //* The scene is composed here, before the first frame. The pre-capture is
    //* decoded synchronously and lock.sh has already finished it, so the
    //* backdrop, the chosen surface style and the default furniture all exist
    //* on that frame. The only motion is the staged entrance and then the
    //* unlock.
    Component.onCompleted: {
        //* No capture polling to arm: lock.sh finished grim before spawning
        //* this process, so the file is already on disk and grimSource binds
        //* straight to it.
        //
        //* Read both files synchronously here rather than leaving it to their
        //* onLoaded signals. blockLoading has the text ready by now, while
        //* onLoaded is delivered after the surface has already committed its
        //* first frame — which is what made the lock start in the default
        //* mode and then visibly switch to the chosen background and style.
        root.flagsReady = root.syncSharedFlags();
        root.syncWallpaperState();
        root.evaluateBackdrop();
        root.evaluateDesign();
        //* If the backdrop and design are already up, reveal on this first
        //* frame. The gate below is only for a decode that is genuinely still
        //* in flight; it is not the normal path.
        if (root.flagsReady && root.wallpaperReady
            && root.backdropReady && root.designReady)
            root.composed = true;
        else
            root.maybeCompose();
        console.log("[lock] compose " + (root.composed ? "first-frame" : "deferred")
            + ": style=" + root.styleLock + " background=" + root.background
            + " design=" + designLoader.status + " wallpaper=" + wallpaperShot.status
            + " flags=" + root.flagsReady + " backdrop=" + root.backdropReady);
        Qt.callLater(() => reportWallpaper("startup"));
    }

    // ── Background ──
    // grim file first (real desktop, captured pre-lock), then ScreencopyView,
    // then wallpaper file. Matches hyprlock `path = screenshot` + Caelestia useWallpaper.
    Item {
        id: bgLayer

        anchors.fill: parent
        //* Opaque from the very first frame, and deliberately NOT animated.
        //* The capture is decoded synchronously before this process paints, so
        //* the backdrop and the furniture appear together rather than the
        //* wallpaper sitting alone while the lock assembles.
        opacity: 1

        // 1) grim pre-capture — most reliable, no ext-session-lock race
        Image {
            id: grimShot

            anchors.fill: parent
            //* lock.sh finishes grim BEFORE spawning this process, so by the
            //* time this binds, the file is complete on disk. That is the
            //* whole point: this used to bind while grim was still encoding,
            //* latch status=Error on a truncated read, and need a timed poll
            //* with a cache-busted URL to recover. An empty source is now only
            //* the genuine no-capture case (grim missing or failed), which the
            //* wallpaper layer behind already handles.
            source: root.grimSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
            //* Capture mode paints it as the backdrop; wallpaper mode uses it
            //* underneath as the exact desktop frame the entrance fades from.
            visible: root.background === "capture" || root.background === "wallpaper"

            //* A grim failure and a not-yet-decoded file look identical on
            //* screen, and the startup report can land before the decode
            //* finishes. Report again when it settles.
            onStatusChanged: {
                root.reportCapture("grimShot status=" + status);
                root.evaluateBackdrop();
                root.maybeCompose();
            }
        }


        // 2) Per-screen live capture when grim missing (Caelestia screencopyBackground).
        // live:false = single frame, avoids DPMS/wake crash loop.
        ScreencopyView {
            id: bgShot

            anchors.fill: parent
            captureSource: root.lockSurface ? root.lockSurface.screen : null
            live: false
            //* Only a fallback for when the grim file is missing or failed to
            //* decode. This used to read `!grimShot.visible`, which is
            //* `background !== "capture"` — the exact inverse of when this
            //* needs to be visible, so it never showed and the fallback was
            //* unreachable in every capture run.
            visible: root.background === "capture" && grimShot.status !== Image.Ready && hasContent
            onHasContentChanged: {
                root.evaluateBackdrop();
                root.maybeCompose();
            }
        }

        // One blurred layer over whichever source is live.
        MultiEffect {
            id: bgBlur

            anchors.fill: parent
            source: grimShot.status === Image.Ready ? grimShot : bgShot
            visible: root.background === "capture" && (grimShot.status === Image.Ready || bgShot.hasContent)
            autoPaddingEnabled: false
            //* The blur RELAXES on the way out instead of the surface fading to
            //* nothing. See the release notes above; blurAt() paces it so the
            //* change is even rather than back-loaded into the final 80ms.
            //*
            //* No Behavior on these: they are bound to `release`, which is
            //* already animated. A Behavior here would re-animate the same
            //* value on top of that and the two would fight.
            blurEnabled: root.composed && root.blurAt(root.release) > 0
            blur: 1
            blurMax: root.blurAt(root.release)
            blurMultiplier: 1
            //* Saturation and brightness are linear perceptual effects, so a
            //* straight ramp is the right shape for them — no curve needed.
            saturation: -0.08 * root.backdropHeld
            brightness: -0.06 * root.backdropHeld
        }

        // 3) Wallpaper — the explicit "wallpaper" choice, and the fallback when
        //    "capture" is on but no capture came back.
        Image {
            id: wallpaperShot

            anchors.fill: parent
            //* Only ever a fallback once the capture has actually failed, never
            //* speculatively. This used to test `!root.capturePending`, which
            //* was true during exactly the window where grim was still writing
            //* the file — so the wallpaper flashed for a split second and was
            //* then covered by the screenshot. lock.sh now completes the
            //* capture before this process starts, so there is no wait window
            //* left to guard against: if the file is not here, grim genuinely
            //* produced nothing.
            visible: root.background === "wallpaper"
                || (root.background === "capture" && grimShot.status !== Image.Ready && !bgShot.hasContent)
            //* With a capture underneath, the wallpaper is part of the lock
            //* layer, so it crossfades in over the exact desktop pixels the
            //* entrance starts from. That crossfade is over by ~45% of the
            //* entrance so the backdrop is settled before the furniture has
            //* finished assembling, rather than still moving underneath it.
            opacity: root.background === "wallpaper" && grimShot.status === Image.Ready
                ? root.stage(0, 0.45, 1)
                : 1
            //* Walk videoBackdropCandidates on failure: shared video still, then
            //* this output's, then the grim capture. `candidate` is reset when
            //* the wallpaper state is (re)read.
            property int candidate: 0
            source: root.videoBackdropCandidates[Math.min(wallpaperShot.candidate, root.videoBackdropCandidates.length - 1)]
            onStatusChanged: {
                if (status === Image.Error && candidate < root.videoBackdropCandidates.length - 1)
                    candidate++;
                root.evaluateBackdrop();
                root.maybeCompose();
            }
            fillMode: Image.PreserveAspectCrop
            //* Decode at screen resolution, never at the file's native size.
            //* A 5842x3286 wallpaper is 19.2 megapixels of RGBA — 77MB of
            //* texture — decoded asynchronously with no cache, into a surface
            //* that has to be correct the instant it appears. That is what
            //* produced the speckled, soft backdrop: the texture was still
            //* being uploaded when the lock drew. Sizing the source to the
            //* screen makes it a cheap, synchronous, correct decode.
            sourceSize.width: root.lockSurface && root.lockSurface.screen
                ? root.lockSurface.screen.width : 1920
            sourceSize.height: root.lockSurface && root.lockSurface.screen
                ? root.lockSurface.screen.height : 1080
            asynchronous: false
            cache: true
            smooth: true
        }

        // Dark veil for text contrast — lighter than before so wallpaper
        // stays visible like the reference (was 0.38/0.52 washing to gray).
        // Rides `backdropHeld` so it is absent from the plain backdrop while the
        // scene composes, and fades back to the bare desktop on unlock.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.3 * root.backdropHeld
        }

        // Extra legibility veil for the finer-grained lock designs on a sharp
        // capture; see designVeil. Invisible for the default lock, for
        // wallpaper/solid, and once the blur is heavy again.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.designVeil * root.backdropHeld
            visible: opacity > 0
        }

        // subtle top/bottom vignette so status icons + pill read like reference
        Rectangle {
            anchors.fill: parent
            opacity: root.backdropHeld

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.18)
                }

                GradientStop {
                    position: 0.3
                    color: Qt.rgba(0, 0, 0, 0)
                }

                GradientStop {
                    position: 0.72
                    color: Qt.rgba(0, 0, 0, 0)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

            }

        }

    }

    // ── Center clock — upper third like reference ──
    ColumnLayout {
        id: clockCol

        visible: root.styleLock === "default"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.13
        spacing: 4
        //* 40-240ms of the entrance, and back down with `held` on unlock.
        opacity: root.stage(40 / root.entranceMs, 240 / root.entranceMs, 1) * root.held

        transform: Translate {
            //* Drifts the remaining 22px to rest over 40-320ms.
            y: -22 * (1 - root.stage(40 / root.entranceMs, 320 / root.entranceMs, 1))
        }

        Label {
            id: dateLabel

            property var now: new Date()

            Layout.alignment: Qt.AlignHCenter
            text: now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
            color: "#ffffff"
            opacity: 0.88
            font.family: "Adwaita Sans"
            font.pointSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering

            Timer {
                running: true
                interval: 15000
                repeat: true
                onTriggered: dateLabel.now = new Date()
            }

        }

        Label {
            id: timeLabel

            property var now: new Date()

            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(timeLabel.now, root.use12h ? "h:mm AP" : "HH:mm")
            color: "#f2f2f2"
            opacity: 0.96
            font.family: "Adwaita Sans"
            font.pointSize: 92
            font.weight: Font.Bold
            // tight tracking like reference 23:49
            font.letterSpacing: -4
            lineHeight: 0.95
            scale: 1
            renderType: Text.NativeRendering

            Timer {
                running: true
                interval: 1000
                repeat: true
                onTriggered: timeLabel.now = new Date()
            }

        }

    }

    // ── Battery pill — top-right status like the reference ──
    LockBattery {
        id: lockBattery

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 26
        anchors.rightMargin: 28
        opacity: root.stage(120 / root.entranceMs, 320 / root.entranceMs, 1) * root.held
        // The component decides whether it has anything to show; showBattery
        // (LOCK surface) is the user's master switch on top of that.
        visible: root.styleLock === "default" && root.showBattery && present
        shimmerOn: root.batteryShimmerOn
    }

    // ── Wifi — top-left status, mirrors the battery corner ──
    LockWifi {
        id: lockWifi

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 26
        anchors.leftMargin: 28
        opacity: root.stage(120 / root.entranceMs, 320 / root.entranceMs, 0.9) * root.held
        // Same arrangement as the battery: its own presence check, gated by the
        // showWifi flag.
        visible: root.styleLock === "default" && root.showWifi && wifiDev !== null
    }

    // per-keystroke password dot
    //
    // This was a port of polkit's CharItem, and it was far too busy. Sampled
    // off a real keystroke, one dot ran 570ms: an OutBack spring overshot to
    // 1.085, the dot then sat frozen at 1.000 for 170ms (a bare PauseAnimation
    // in the middle of the sequence), and it finally shrank to 0.667 and
    // *stayed* there. Its width animated 15.6 -> 12.0 on top of that. Type a
    // password at speed and five dots are mid-cycle simultaneously, sitting at
    // three different scales, with the older ones visibly smaller than the
    // new one.
    //
    // Now one keystroke is one ramp: opacity 0 -> 1 and scale 0.6 -> 1, both
    // OutCubic over 130ms. No overshoot, no pause, no second motion on the
    // width, and it settles at 1.0 rather than 2/3.
    //
    // The rect is 0.8 * implicitHeight where it used to be 1.2 *, which is
    // what keeps the resting size identical: 1.2 * 2/3 == 0.8, so a dot is
    // still exactly 9.6px once the animation ends. Without that the move to
    // scale 1.0 would have silently grown every resting dot by 50%.
    component DotItem: Item {
        id: dot

        required property int index

        //* Static, and 1.0 * implicitHeight, which is what the old animation
        //* settled on — so row spacing is unchanged. Animating a layout
        //* property also had the ListView re-flowing under the animation.
        implicitWidth: dotList.implicitHeight
        implicitHeight: dotList.implicitHeight

        Rectangle {
            id: dotRect

            anchors.centerIn: parent
            width: dotList.implicitHeight * 0.8
            height: dotList.implicitHeight * 0.8
            radius: width / 2
            color: "#ffffff"
            opacity: 0
            scale: 0.6

            ParallelAnimation {
                id: initAnim

                running: true

                NumberAnimation {
                    target: dotRect
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 130
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: dotRect
                    property: "scale"
                    from: 0.6
                    to: 1
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: dot
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: dotRect
                        property: "opacity"
                        to: 0
                        duration: 130
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: dotRect
                        property: "scale"
                        to: 0.5
                        duration: 130
                    }
                }
                PropertyAction {
                    target: dot
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }

    // ── Bottom auth cluster ──
    ColumnLayout {
        id: authCol

        visible: root.styleLock === "default"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 9
        //* 80-280ms, behind the clock, and back down with `held`.
        opacity: root.stage(80 / root.entranceMs, 280 / root.entranceMs, 1) * root.held

        transform: Translate {
            //* Rises its remaining 26px over 80-360ms.
            y: 26 * (1 - root.stage(80 / root.entranceMs, 360 / root.entranceMs, 1))
        }

        // avatar — ClippingRectangle clips to radius (plain clip ignores it)
        Item {
            id: avatarBox

            Layout.alignment: Qt.AlignHCenter
            width: 64
            height: 64
            visible: root.showAvatar

            ClippingRectangle {
                anchors.fill: parent
                radius: 32
                color: "#232323"

                Image {
                    id: faceImg

                    anchors.fill: parent
                    //* Guarded on avatarWanted, not just on the URL. With no
                    //* path the source would be "file://" on its own, which
                    //* is a directory-shaped URL that fails on its own terms
                    //* and lands in the same Error branch as a real missing
                    //* file — two different situations, one accidental code
                    //* path.
                    source: root.avatarWanted ? "file://" + root.facePath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Label {
                    id: fallback

                    anchors.centerIn: parent
                    //* Either there is no image, or the one that was asked for
                    //* would not load. Both read the same to the user: show
                    //* the person glyph.
                    visible: !root.avatarWanted || faceImg.status === Image.Error
                    //* U+F007, nf-fa-user. This was an empty string, so with
                    //* no ~/.face to fall back on the avatar was a bare grey
                    //* disc — the glyph went missing the same way the lock
                    //* and return glyphs did when LockShape was dropped.
                    text: ""
                    color: "#d8d8d8"
                    font.family: "JetBrainsMono NFM"
                    font.pointSize: 20
                }

            }

            Rectangle {
                anchors.fill: parent
                radius: 32
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
            }

        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            color: "#ffffff"
            opacity: 0.9
            font.family: "Adwaita Sans"
            font.pointSize: 10
            font.weight: Font.Medium
        }

        // password pill
        Rectangle {
            id: pillBg

            Layout.alignment: Qt.AlignHCenter
            // polkit-style: pill breathes wider while typing
            implicitWidth: context.currentText.length > 0 ? 268 : 208
            implicitHeight: 40
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1]
                }
            }
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            radius: 19
            color: context.showFailure ? Qt.rgba(1, 0.42, 0.42, 0.16) : Qt.rgba(1, 1, 1, 0.14)
            border.color: context.showFailure ? "#ff7a7a" : (root.activeFocus ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18))
            border.width: 1

            // polkit failShake: -12 / 10 / -6 / 0 with quad easings
            SequentialAnimation {
                id: shake

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: -12
                    duration: 60
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: 10
                    duration: 80
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: -6
                    duration: 80
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: 0
                    duration: 80
                    easing.type: Easing.OutQuad
                }

            }

            Connections {
                function onShowFailureChanged() {
                    if (root.context.showFailure)
                        shake.start();

                }

                target: root.context
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                // lock icon — reddens on error like polkit
                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    Label {
                        anchors.centerIn: parent
                        visible: !context.unlockInProgress
                        //* U+F023, nf-fa-lock. This was an empty string: the
                        //* glyph was lost when LockShape was dropped, leaving
                        //* a bare 26px gap at the left end of the pill.
                        text: "\uf023"
                        color: root.fieldInError ? "#ff7a7a" : Qt.rgba(1, 1, 1, 0.6)
                        font.family: "JetBrainsMono NFM"
                        font.pointSize: 11

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }

                        }

                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        visible: context.unlockInProgress
                        running: visible
                        implicitWidth: 15
                        implicitHeight: 15
                    }

                }

                // middle: animated placeholder + the password dots.
                // Nothing in here captures input. There used to be an
                // invisible TextField filling this cell, which put the
                // compositor's text-input protocol between the keyboard and
                // the password -- and it dropped characters inside the
                // session lock, turning a correct password into a 3
                // character one that PAM rejected. root's Keys.onPressed
                // owns input now, so this cell is purely visual.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Label {
                        id: pillPlaceholder

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        text: root.fieldInError ? "Incorrect password" : "Enter password"
                        color: root.fieldInError ? "#ff7a7a" : Qt.rgba(1, 1, 1, 0.5)
                        font.family: "Adwaita Sans"
                        font.pointSize: 9
                        opacity: context.currentText.length > 0 || context.unlockInProgress ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }

                        }

                    }

                    ListView {
                        id: dotList
                        // simple width math (avoids `as` cast on inline type — crashes qmllint)
                        readonly property int fullWidth: count * (implicitHeight + spacing)

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0
                        implicitWidth: fullWidth
                        implicitHeight: 12
                        orientation: Qt.Horizontal
                        spacing: 6
                        interactive: false
                        visible: !context.unlockInProgress

                        model: ScriptModel {
                            values: context.currentText.split("")
                        }

                        delegate: DotItem {
                        }

                    }

                }

                // enter button — circle morphs into arrow while typing like polkit
                Item {
                    id: enterButton

                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    visible: !context.unlockInProgress

                    Rectangle {
                        id: enterCircle

                        anchors.fill: parent
                        radius: width / 2
                        color: context.currentText.length > 0 ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, 0.22)
                        scale: context.currentText.length === 0 ? 0.62 : enterMouse.pressed ? 0.6 : enterMouse.containsMouse ? 0.8 : 0.7

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                        }

                        //* U+E862, nf-fa-return.
                        //*
                        //* This circle used to carry no glyph at all, and that
                        //* is what the "extra dot" in the password field was: a
                        //* bright white circle sitting ~30px from a row of 10px
                        //* white password dots — same colour, same shape,
                        //* nearly twice the diameter. Measured on a rendered
                        //* pill: ten 10x10 dots and one 18x18 circle, with
                        //* nothing in the lock-icon slot to balance it. The
                        //* arrow makes it read as a button instead.
                        //*
                        //* The glyph inverts with the button. The circle goes
                        //* from 0.22 white (dim, so the glyph stays light) to
                        //* 0.92 white (bright, so the glyph has to go dark).
                        Label {
                            anchors.centerIn: parent
                            text: "\ue862"
                            font.family: "JetBrainsMono NFM"
                            font.pointSize: 10
                            color: context.currentText.length > 0 ? "#14181a" : Qt.rgba(1, 1, 1, 0.75)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }

                            }

                        }

                        MouseArea {
                            id: enterMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: context.currentText.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (context.currentText.length > 0)
                                    context.tryUnlock();

                            }

                        }

                    }

                }

            }

            // centered in the whole pill (not the middle row — siblings
            // hide/show while checking and would offset a row-centered label)
            // shimmer "Authenticating" (shadcn-style: dim base + bright sweep,
            // 2s linear loop). Self-contained: no shared imports allowed here.
            Item {
                id: authShimmer

                anchors.centerIn: parent
                width: authBase.implicitWidth
                height: authBase.implicitHeight
                opacity: context.unlockInProgress ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                Label {
                    id: authBase

                    anchors.centerIn: parent
                    text: "Authenticating"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: "Adwaita Sans"
                    font.pointSize: 9
                    renderType: Text.NativeRendering
                }

                Item {
                    id: sheenMover

                    width: Math.max(60, authShimmer.width * 0.5)
                    height: authShimmer.height

                    readonly property real coreWidth: Math.max(24, authShimmer.width * 0.22)

                    Item {
                        anchors.fill: parent
                        clip: true

                        Label {
                            // y: math, not anchors.verticalCenter —
                            // authShimmer is not a parent or sibling of this
                            // label, so anchoring across that boundary is
                            // refused at runtime and logged as
                            // "Cannot anchor to an item that isn't a parent
                            // or sibling" on every single lock.
                            y: (authShimmer.height - implicitHeight) / 2
                            x: (authShimmer.width - implicitWidth) / 2 - sheenMover.x
                            width: implicitWidth
                            height: implicitHeight
                            text: "Authenticating"
                            color: "#ffffff"
                            opacity: 0.45
                            font.family: "Adwaita Sans"
                            font.pointSize: 9
                            renderType: Text.NativeRendering
                        }

                    }

                    Item {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: sheenMover.coreWidth
                        clip: true

                        Label {
                            // same y: math as the label above
                            y: (authShimmer.height - implicitHeight) / 2
                            x: (authShimmer.width - implicitWidth) / 2 - sheenMover.x - (sheenMover.width - sheenMover.coreWidth) / 2
                            width: implicitWidth
                            height: implicitHeight
                            text: "Authenticating"
                            color: "#ffffff"
                            font.family: "Adwaita Sans"
                            font.pointSize: 9
                            renderType: Text.NativeRendering
                        }

                    }

                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: authShimmer.visible
                        PauseAnimation {
                            duration: 250
                        }

                        NumberAnimation {
                            from: -sheenMover.width
                            to: authShimmer.width
                            duration: 2000
                            easing.type: Easing.Linear
                        }

                    }

                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }

            }

        }

    }

    // ── Media — under the clock, its own MPRIS transport ──
    LockMedia {
        id: lockMedia

        host: root
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockCol.bottom
        anchors.topMargin: 28
        //* 120-320ms, following the auth cluster.
        opacity: root.stage(120 / root.entranceMs, 320 / root.entranceMs, 1) * root.held
        // Visible only for default style; designs provide their own media card
        visible: root.styleLock === "default"
    }

    // ── Selected design ──
    //
    // Everything above stays the untouched default; a non-default style loads
    // its layout here. The designs share this surface's key handler, PAM
    // context, flags and backdrop, and each places its own live media card,
    // wifi and battery so no functionality is lost when the skin changes.
    Loader {
        id: designLoader

        anchors.fill: parent
        active: root.styleLock !== "default"
        sourceComponent: root.styleLock === "relay" ? relayLock
            : root.styleLock === "folio" ? folioLock
            : root.styleLock === "editorial" ? editorialLock
            : root.styleLock === "phase" ? phaseLock
            : root.styleLock === "spine" ? spineLock
            : root.styleLock === "reactive" ? reactiveLock
            : null
        onStatusChanged: {
            root.evaluateDesign();
            root.maybeCompose();
        }
    }

    Component { id: relayLock; LockRelay { host: root } }
    Component { id: folioLock; LockFolio { host: root } }
    Component { id: editorialLock; LockEditorial { host: root } }
    Component { id: phaseLock; LockPhase { host: root } }
    Component { id: spineLock; LockSpine { host: root } }
    Component { id: reactiveLock; LockReactive { host: root } }

    // keep focus on the key handler (Hyprland unfocuses on wake — Noctalia
    // workaround). root is what owns Keys.onPressed now, so this has to
    // re-focus root; while a child held focus the password would silently
    // stop accepting keystrokes.
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!root.activeFocus && !context.unlockInProgress)
                root.forceActiveFocus();

        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onEntered: {
            if (!root.activeFocus && !context.unlockInProgress)
                root.forceActiveFocus();

        }
    }

}
