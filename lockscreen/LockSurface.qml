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
    readonly property string stateWallpaper: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/ukishima-wallpaper"
    readonly property string wallpaperFallback: home + "/Pictures/Wallpapers/current_wallpaper.jpg"
    //* The wallpaper the shell is actually showing, read from the same state
    //* file Singletons/Walls.qml writes (ukishima-wallpaper holds the current
    //* wallpaper's path, one line). The lockscreen runs as its own process and
    //* cannot import Singletons, so it re-reads the file itself. Falls back to
    //* the legacy current_wallpaper.jpg only when that state file is missing.
    property string currentWallpaper: ""
    readonly property string wallpaperSource: currentWallpaper.length > 0 ? currentWallpaper : wallpaperFallback
    //* A video file cannot be painted by an Image, and the shell's wallpaper
    //* dir scan happily writes one (.mp4/.webm/.mkv/.mov) into the state file
    //* — locking on a video wallpaper used to land this layer on status=Error
    //* and paint nothing but the base colour. lock.sh grim-captures the desktop
    //* on every lock regardless of mode, and that capture IS the video's
    //* current frame, so it takes over. If the capture is missing too, the
    //* Image errors and the base colour shows, same as any other absent
    //* backdrop.
    readonly property bool wallpaperIsVideo: /\.(mp4|webm|mkv|mov)$/i.test(wallpaperSource)

    //* lock.sh redirects the lock's stderr into its own log
    //* (${XDG_CACHE_HOME:-$HOME/.cache}/ukishima/lock.log), so one
    //* console.log per lock says exactly which file the backdrop resolved to and
    //* whether it came from the state file or the legacy fallback. Without it,
    //* "the lock shows the wrong wallpaper" is unanswerable from outside the
    //* session.
    function reportWallpaper(how) {
        console.log("[lock] wallpaper " + how + ": mode=" + background
            + " state=" + stateWallpaper
            + " current=" + (currentWallpaper || "<empty>")
            + " using=" + (wallpaperIsVideo ? lockShot + " (capture, video wallpaper)" : wallpaperSource)
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
    //* Read from the desktop's reduceMotion setting. When it is on, the lock
    //* skips the entrance choreography entirely and paints its final state on
    //* the first frame. The staggered fade/zoom/translate is exactly the kind
    //* of motion that setting exists to suppress, and honouring it here also
    //* gives anyone who finds the lock sluggish a one-setting way out.
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
    readonly property string grimSource: background === "capture"
        ? "file://" + lockShot
        : ""

    //* Re-report if the mode changes after load, so a lock that starts in the
    //* default and is then pointed at "capture" still says what it painted.
    onBackgroundChanged: {
        root.captureLogged = false;
        root.reportCapture("mode=" + background);
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
        } catch (e) {
        }
        //* Now that reduceMotion is known, the entrance can start.
        root.startEntrance();
    }

    FileView {
        id: sharedFlags

        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.syncSharedFlags()
        onFileChanged: reload()
        onLoadFailed: {
            root.use12h = false;
            root.batteryShimmerOn = true;
            root.showAvatar = true;
            root.showWifi = true;
            root.showBattery = true;
            root.showMedia = true;
            root.blurMax = 64;
            root.background = "capture";
            root.avatarPath = "";
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
            root.reportWallpaper("loaded");
        }
        onFileChanged: reload()
        onLoadFailed: {
            root.currentWallpaper = "";
            root.reportWallpaper("load-failed");
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

    //* How "still a lock screen" this is right now. The furniture reads this
    //* directly; the backdrop reads the curve below.
    readonly property real held: 1 - Math.max(0, Math.min(1, root.release))

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

    // entrance choreography, Caelestia initAnim style:
    // the clock drifts down and the auth cluster rises, staggered so the
    // lock "assembles" smoothly
    Component.onCompleted: {
        //* No capture polling to arm: lock.sh finished grim before spawning
        //* this process, so the file is already on disk and grimSource binds
        //* straight to it.
        //* The entrance is NOT started here. reduceMotion lives in the shared
        //* flags file, which loads asynchronously, so at onCompleted it is
        //* still the default `false` -- starting the animation then ran the
        //* full choreography for everyone, including users who had asked for
        //* reduced motion. startEntrance() is called once the flags are known.
        entranceFallback.start();
        Qt.callLater(() => reportWallpaper("startup"));
    }

    //* Start the entrance at most once, honouring reduceMotion.
    property bool entranceStarted: false

    function startEntrance() {
        if (entranceStarted)
            return;
        entranceStarted = true;
        if (reduceMotion) {
            //* Snap to the end state instead of skipping the entrance. Skipping
            //* was a real bug: every element derives its opacity from
            //* `entrance`, and nothing but the animation ever moved it, so a
            //* reduced-motion lock screen had no clock, no password field and
            //* no indicators — the UI needed to actually unlock, gone.
            //* Honouring reduced motion means no *motion*, not no *content*.
            entrance = 1;
            console.log("[lock] reduceMotion on -- entrance applied without motion");
            return;
        }
        showAnim.start();
    }

    //* If the flags file never arrives (missing, unreadable, a partial write),
    //* still run the entrance rather than leaving every element stuck at
    //* opacity 0 on a locked screen.
    Timer {
        id: entranceFallback

        interval: 300
        onTriggered: root.startEntrance()
    }

    //* Entrance choreography: the clock drifts down, the auth cluster rises,
    //* the corner indicators follow — staggered so the lock "assembles"
    //* smoothly, all inside ~380ms.
    //*
    //* These were 450/750/90/180/140ms over 500-600ms eases, which put the last
    //* element at 780ms after the first frame. Combined with process startup
    //* that is a ~2s lock, and the long tail is why it read as sluggish rather
    //* than merely brief.
    //*
    //* The backdrop is not animated at all any more. It used to fade from 0
    //* over 220ms, which held the WlSessionLockSurface's #0b0d0c on screen —
    //* black on black — for that whole window, and that was the flash on the
    //* way in. (Its `scale` zoom had already gone: bgLayer holds a full-screen
    //* MultiEffect, so animating scale re-rasterised a 1920x1200 blur on every
    //* frame, for a 5% zoom on an image nobody could see moving.) lock.sh
    //* finishes the capture before this process starts, so there is nothing to
    //* reveal; the furniture carries the entrance by itself.
    //
    //* One master value rather than a NumberAnimation per element. An animation
    //* assigns its target property directly, which BREAKS that property's
    //* declarative binding — so animating `clockCol.opacity` and also binding
    //* it to `* root.held` would quietly stop working the instant the
    //* entrance finished, stranding the clock and the password field on screen
    //* through the unlock. Every element below stays a plain expression off
    //* `entrance` and `held`, so the unlock fade is exact and free.
    property real entrance: 0

    //* Map the master clock onto one element's window. `from`/`to` are
    //* fractions of the entrance, `peak` the value it settles at.
    //*
    //* The OutCubic is applied per stage, not to the master clock, so each
    //* element keeps exactly the curve it had as a standalone NumberAnimation.
    //* Easing the master and remapping linearly would flatten every stage into
    //* the same shape.
    //*
    //* Windows are the original absolute milliseconds divided by entranceMs:
    //* clock 40-240 (opacity) and 40-320 (drift), auth 80-280 and 80-360,
    //* indicators 120-320.
    function stage(from, to, peak) {
        const u = Math.max(0, Math.min(1, (root.entrance - from) / (to - from)));
        return (1 - Math.pow(1 - u, 3)) * peak;
    }
    readonly property int entranceMs: 380

    NumberAnimation {
        id: showAnim

        target: root
        property: "entrance"
        from: 0
        to: 1
        duration: root.entranceMs
    }

    // ── Background ──
    // grim file first (real desktop, captured pre-lock), then ScreencopyView,
    // then wallpaper file. Matches hyprlock `path = screenshot` + Caelestia useWallpaper.
    Item {
        id: bgLayer

        anchors.fill: parent
        //* Opaque from the very first frame, and deliberately NOT animated.
        //* This used to start at 0 and fade in over 220ms, which meant the
        //* WlSessionLockSurface's own #0b0d0c was on screen — black on black —
        //* for that whole window even though the capture had been finished and
        //* decoded before this process was even spawned. That was the flash on
        //* the way in. The capture is guaranteed present now, so there is
        //* nothing to reveal and nothing to wait for; the clock and the auth
        //* cluster still animate in, which is where the entrance reads from.
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
            visible: root.background === "capture"

            //* A grim failure and a not-yet-decoded file look identical on
            //* screen, and the startup report can land before the decode
            //* finishes. Report again when it settles.
            onStatusChanged: root.reportCapture("grimShot status=" + status)
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
            blurEnabled: root.blurAt(root.release) > 0
            blur: 1
            blurMax: root.blurAt(root.release)
            blurMultiplier: 1
            //* Saturation and brightness are linear perceptual effects, so a
            //* straight ramp from `held` is the right shape for them — no
            //* curve needed.
            saturation: -0.08 * root.held
            brightness: -0.06 * root.held
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
            source: "file://" + (root.wallpaperIsVideo ? root.lockShot : root.wallpaperSource)
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
        // stays visible like the reference (was 0.38/0.52 washing to gray)
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.3
        }

        // subtle top/bottom vignette so status icons + pill read like reference
        Rectangle {
            anchors.fill: parent

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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.13
        spacing: 4
        //* 40-240ms of the entrance, and back down with `held` on unlock.
        opacity: root.stage(40 / root.entranceMs, 240 / root.entranceMs, 1) * root.held

        transform: Translate {
            id: clockShift
            //* Drifts the remaining 22px to rest over 40-320ms. The base y was
            //* -22 while the old animation started from -14, so the clock
            //* visibly jumped 8px the instant the entrance began; the drift now
            //* continues from where the element actually sits.
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
        visible: root.showBattery && present
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
        visible: root.showWifi && wifiDev !== null
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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 9
        //* 80-280ms, behind the clock, and back down with `held`.
        opacity: root.stage(80 / root.entranceMs, 280 / root.entranceMs, 1) * root.held

        transform: Translate {
            id: authShift
            //* Rises its remaining 26px over 80-360ms. Same 10px jump as the
            //* clock used to have; see clockShift.
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

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockCol.bottom
        anchors.topMargin: 28
        // Same window as the battery/wifi corners, and back down with `held`
        // on unlock. clockCol.bottom is the layout edge, so the clock's drift
        // transform never drags the card along with it.
        opacity: root.stage(120 / root.entranceMs, 320 / root.entranceMs, 1) * root.held
        // Same arrangement as the corners: the card's own presence check
        // (hasPlayer, its binding inside LockMedia) and the showMedia flag
        // from the LOCK settings on top of that — this instance-level binding
        // replaces the internal one, so both halves live here.
        visible: root.showMedia && hasPlayer
    }

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
