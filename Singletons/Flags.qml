import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every Pill daemon (pill, lock) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias time12h: adapter.time12h
    property alias clockSeconds: adapter.clockSeconds
    property alias mainDisplay: adapter.mainDisplay
    property alias expandTo: adapter.expandTo
    property alias showGlyphs: adapter.showGlyphs
    //* Resting pill's clock icon, left of the time. Only drawn when showGlyphs is off — the two are alternatives in the same slot, \u6642 or a clock face.
    property alias clockIcon: adapter.clockIcon
    property alias paletteMode: adapter.paletteMode
    property alias wallpaperDir: adapter.wallpaperDir
    property alias wallpaperFit: adapter.wallpaperFit
    property alias uiScale: adapter.uiScale
    property alias reduceMotion: adapter.reduceMotion
    property alias manualHue: adapter.manualHue
    property alias manualDark: adapter.manualDark
    property alias manualSat: adapter.manualSat
    //* The dock's own manual hue — fully independent of the pill's manual flags.
    property alias dockManualHue: adapter.dockManualHue
    property alias dockManualSat: adapter.dockManualSat
    property alias dockManualDark: adapter.dockManualDark
    //* Accent override: a "#rrggbb" hex that wins over the Light/Dark default, the
    //* wallpaper accent and the manual hue for every warm token. Empty follows the scheme.
    property alias accentOverride: adapter.accentOverride
    //* Text override: a "#rrggbb" hex that recolours the primary text family (cream/bright
    //* on the pill, the dock's title copy) across the shell and the dock. Empty follows the scheme.
    property alias textOverride: adapter.textOverride
    property alias uiFont: adapter.uiFont
    property alias pillOpacity: adapter.pillOpacity
    property alias glass: adapter.glass
    //* Text-visibility boost when transparency mode is on: 0 (off) to 1 (strong) — lifts the readability veil behind copy so pale text keeps contrast on bright wallpapers.
    property alias glassText: adapter.glassText
    property alias autoHide: adapter.autoHide
    //* Bottom dock: macOS-style pinned + running app bar on every monitor.
    property alias dockEnabled: adapter.dockEnabled
    //* Dock hides below the screen edge and slides back up on bottom-edge hover; off keeps it reserved and always visible.
    property alias dockAutoHide: adapter.dockAutoHide
    //* Dock palette theme, mirroring the pill's: "light"/"dark"/"dynamic"/"manual" — the dock resolves its own palette, independent of the pill's.
    property alias dockTheme: adapter.dockTheme
    //* Dock pane depth: "transparent" lets the desktop glow through, "solid" paints the pane opaque.
    property alias dockStyle: adapter.dockStyle
    //* Minimal dock: icon-only chips with the small active dot, no inline title label.
    property alias dockMinimal: adapter.dockMinimal
    property alias topGap: adapter.topGap
    property alias appGap: adapter.appGap
    property alias recordCountdown: adapter.recordCountdown
    property alias recordDir: adapter.recordDir
    property alias recordFps: adapter.recordFps
    property alias recordQuality: adapter.recordQuality
    property alias recordCursor: adapter.recordCursor
    property alias recordMic: adapter.recordMic
    property alias recordDesktop: adapter.recordDesktop
    property alias recordClearedBefore: adapter.recordClearedBefore
    property alias weatherCity: adapter.weatherCity
    property alias musicViz: adapter.musicViz
    property alias gameMode: adapter.gameMode
    //* Game mode's snapshot slot per flag it disturbs. The first three are
    //* load-bearing: GameMode.enter() writes them and leave() reads them back, so
    //* dropping one does not throw -- the desktop just stays quiet after a game
    //* because the pre-game value was never restored. They look identical to
    //* gamePrevProfile below, which a pass that prunes "unused flags" could take
    //* for dead, so it is one line away from taking the block with it. Prune per
    //* flag, never as a group. gamePrevProfile holds the power profile (as a
    //* string-encoded PowerProfile value) that game mode replaced with
    //* Performance; "" means game mode did not change it.
    property alias gamePrevDnd: adapter.gamePrevDnd
    property alias gamePrevViz: adapter.gamePrevViz
    property alias gamePrevAwake: adapter.gamePrevAwake
    property alias gamePrevProfile: adapter.gamePrevProfile
    property alias nightLightMode: adapter.nightLightMode
    property alias nightLightTemp: adapter.nightLightTemp
    property alias nightLightOnMin: adapter.nightLightOnMin
    property alias nightLightOffMin: adapter.nightLightOffMin
    property alias memorySaver: adapter.memorySaver
    property alias unloadSec: adapter.unloadSec
        //* Session lock: show the avatar above the username on lockscreen/LockSurface.qml.
        property alias lockShowAvatar: adapter.lockShowAvatar
        //* Session lock: show the wifi indicator on lockscreen/LockSurface.qml.
        property alias lockShowWifi: adapter.lockShowWifi
        //* Session lock: show the battery indicator on lockscreen/LockSurface.qml.
        property alias lockShowBattery: adapter.lockShowBattery
        //* Session lock: show the media player card under the clock on lockscreen/LockSurface.qml.
        property alias lockShowMedia: adapter.lockShowMedia
        //* Session lock: how hard the captured desktop is blurred behind the lock.
        property alias lockBlur: adapter.lockBlur
        //* Session lock: "capture" grim-captures the desktop at lock time and blurs it, "wallpaper" uses the live wallpaper, "solid" paints an opaque backdrop.
        property alias lockBackground: adapter.lockBackground
        //* Which lock to take: "hyprlock" hands off to your own hyprlock.conf, "quickshell" runs the Quickshell lockscreen (which falls back to hyprlock by itself). Both are dispatched by scripts/lock.sh, which reads this flag, so the pill's power menu and any keybind stay in sync.
        property alias lockMethod: adapter.lockMethod
        //* Path to the avatar image shown on the lockscreen. Empty = none, and the lock draws a person glyph.
        property alias lockAvatarPath: adapter.lockAvatarPath

    FileView {
        id: file

        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                writeAdapter();

        }

        JsonAdapter {
            id: adapter

            property bool dnd: false
            property bool keepAwake: false
            property bool time12h: false
            property bool clockSeconds: false
            //* Collapsed-pill face: "minimal" (glyph + time), "classic" (date + time), "system" (weekday, time, workspace, layout, battery) or "strip" (full-width top bar).
            property string mainDisplay: "minimal"
            //* What the media card's Expand control opens: "media" keeps the surface as the main screen, "pill" swaps to the expanded pill. With auto-hide off, "media" also makes hovering the resting pill grow into the player.
            property string expandTo: "pill"
            property bool showGlyphs: true
            //* Resting pill's clock icon, left of the time. Only drawn when showGlyphs is off — the two are alternatives in the same slot, \u6642 or a clock face.
            property bool clockIcon: true
            property string paletteMode: "static"
            //* Explicit wallpaper folder override. Empty means autodetect: the dir wallpaper.sh last resolved (ukishima-wallpaper-dir state file), then ~/Pictures/Wallpapers. Lives in user state so an in-app update never clobbers a custom folder.
            property string wallpaperDir: ""
            //* Still/video wallpaper scaling: awww --resize "no" (center), "crop" (cover), "fit" (contain) or "stretch", driving the strip's Cover/Contain/Stretch/Center control.
            property string wallpaperFit: "crop"
            property real uiScale: 1
            property bool reduceMotion: false
            property int manualHue: 30
            property bool manualDark: true
            property real manualSat: 0.5
            property int dockManualHue: 30
            property bool dockManualDark: true
            property real dockManualSat: 0.5
            //* Accent override: a "#rrggbb" hex that wins over the Light/Dark default, the
            //* wallpaper accent and the manual hue for every warm token. Empty follows the scheme.
            property string accentOverride: ""
            //* Text override: a "#rrggbb" hex that recolours the primary text family
            //* (cream/bright on the pill, the dock's title copy). Empty follows the scheme.
            property string textOverride: ""
            property string uiFont: ""
            property real pillOpacity: 1
            //* Transparency mode: translucent tinted slab over the desktop. Off restores the exact legacy flat gradient.
            property bool glass: true
            //* Text-visibility boost when glass is on (0..1): lifts the readability veil behind copy so text keeps contrast on bright wallpapers. Persisted in the settings file like every other flag.
            property real glassText: 0
            property bool autoHide: true
            //* Bottom dock: macOS-style pinned + running app bar on every monitor.
            property bool dockEnabled: true
            //* Dock hides below the screen edge and slides back up on bottom-edge hover; off keeps it reserved and always visible.
            property bool dockAutoHide: true
            //* Dock palette theme, mirroring the pill's: "light"/"dark"/"dynamic"/"manual".
            property string dockTheme: "dark"
            //* Dock pane depth: "transparent" lets the desktop glow through, "solid" paints the pane opaque.
            property string dockStyle: "transparent"
            //* Minimal dock: icon-only chips with the small active dot, no inline title label.
            property bool dockMinimal: false
            //* Top margin as a fraction of the shipped 8px. 0 sits the pill flush to the screen edge.
            property real topGap: 1
            //* Pill-to-window band as a fraction of the shipped 12px. 0 tucks the windows flush under the pill.
            property real appGap: 1
            property int recordCountdown: 5
            property string recordDir: ""
            property int recordFps: 60
            property string recordQuality: "high"
            property bool recordCursor: true
            property bool recordMic: true
            property bool recordDesktop: true
            property real recordClearedBefore: 0
            property string weatherCity: ""
            property bool musicViz: true
            property bool gameMode: false
            property bool gamePrevDnd: false
            property bool gamePrevViz: true
            property bool gamePrevAwake: false
            property string gamePrevProfile: ""
            property string nightLightMode: "off"
            property int nightLightTemp: 4000
            property int nightLightOnMin: 1260
            property int nightLightOffMin: 450
            //* Drop closed surfaces after their own idle tier instead of holding them in RAM all session.
            property bool memorySaver: true
            //* Wallpaper-tier idle in seconds when memorySaver is on; the other tiers scale off it.
            property real unloadSec: 30
            //* Session lock: show the avatar above the username on lockscreen/LockSurface.qml.
            property bool lockShowAvatar: true
            //* Session lock: show the wifi indicator on lockscreen/LockSurface.qml.
            property bool lockShowWifi: true
            //* Session lock: show the battery indicator on lockscreen/LockSurface.qml.
            property bool lockShowBattery: true
            //* Session lock: show the media player card under the clock on lockscreen/LockSurface.qml.
            property bool lockShowMedia: true
            //* Session lock: how hard the captured desktop is blurred behind the lock.
            property int lockBlur: 64
            //* Session lock: "capture" grim-captures the desktop at lock time and blurs it, "wallpaper" uses the live wallpaper, "solid" paints an opaque backdrop.
            property string lockBackground: "capture"
            //* Which lock to take: "hyprlock" hands off to your own hyprlock.conf, "quickshell" runs the Quickshell lockscreen (which falls back to hyprlock by itself). Both are dispatched by scripts/lock.sh, which reads this flag, so the pill's power menu and any keybind stay in sync.
            property string lockMethod: "hyprlock"
            //* Path to the avatar image shown on the lockscreen. Empty = none, and the lock draws a person glyph.
            property string lockAvatarPath: ""
        }

    }

}
