pragma Singleton
import QtQuick
import Quickshell

/**
 * Pill palette. Two sources: the curated light/dark hex below is the identity
 * and the default, used whenever the theme is on Light or Dark. On Dynamic the
 * surfaces and the whole accent ramp follow the wallpaper through the matugen-fed
 * `Dyn` singleton. On Manual the same ramp is built locally from the pill's OWN
 * hue flags through `PaletteHue` (the exact wallcolors.py --hue math, rendered
 * in QML) — no shared colors.json rewrite, so dragging the pill slider recolours
 * the pill and its rice side effects only, never the dock. The text family, light
 * veils and shadow stay locked here so copy keeps its contrast on any generated
 * background. Each token is a single ternary, so the static modes render
 * byte-identical to the fixed themes and only the colours that should breathe
 * with the wallpaper do.
 */
Singleton {
    /** Legacy "static" (the old warm-brown theme) maps onto the black pill. */
    readonly property string mode: Flags.paletteMode === "static" ? "dark" : Flags.paletteMode
    readonly property bool dynamic: mode === "dynamic"
    readonly property bool manual: mode === "manual"
    // dyn stays true for manual too so every consumer that just needs "follow
    // the active scheme" (glass tint, today cell, flame ramp) keeps working; the
    // per-token ternaries below pick between the local manual palette and the
    // wallpaper one.
    readonly property bool dyn: mode === "dynamic" || mode === "manual"
    readonly property bool light: mode === "light"

    /**
     * Local manual palette: the wallcolors.py --hue math computed from the
     * pill's own hue flags inside QML. Nothing here reads or writes the shared
     * colors.json, so the dock's dynamic palette (still Dyn) never moves when
     * the pill's manual controls do. Always built, mode-independent, so a
     * palette-mode flip can never expose an empty object to the tokens below
     * mid-update — the `manual` guards decide when it is actually used.
     */
    readonly property var manualPal: PaletteHue.build(Flags.manualHue, Flags.manualSat, Flags.manualDark)

    /**
     * User accent override: a "#rrggbb" hex, empty to follow the scheme. When set
     * it wins for every warm token below (verm ramps, flame ink, charging glow,
     * today cell) no matter what the palette mode derives, and the container pair
     * is rebuilt with darker/lighter math since an arbitrary accent has no
     * material container colours of its own.
     */
    readonly property string customHex: Flags.accentOverride
    readonly property bool customAccent: customHex.length > 0
    /** Effective accent base — the override, else the wallpaper/hue accent, else the warm default. */
    readonly property color accent: customAccent ? customHex : (manual ? manualPal.primary : (dynamic ? Dyn.primary : "#ff9a64"))
    /** Deep pair, standing in where the scheme has a matugen container colour. */
    readonly property color accentDeep: customAccent ? Qt.darker(accent, 1.45) : (manual ? manualPal.primary_container : (dynamic ? Dyn.primaryContainer : "#a3371f"))

    /**
     * User text-colour override: a "#rrggbb" hex, empty to follow the scheme.
     * When set it wins for the primary text (cream) and the brightest token
     * (bright) on every surface, and the glyph/icon tint (iconDim) follows as a
     * muted alpha wash so bar icons (wifi, calendar, workspaces...) carry the
     * colour without shouting. The text secondaries (dim, faint, subtle,
     * tickRest) keep their own scheme values so sub-copy stays legible beside a
     * custom colour, and the alpha-derived veils (hair, sheen, frame*) follow
     * cream automatically.
     */
    readonly property string customTextHex: Flags.textOverride
    readonly property bool customText: customTextHex.length > 0

    /**
     * Literal "#rrggbb" serialization for the flame canvas ramp, which reads raw
     * hex strings (a color property would serialize to #aarrggbb and corrupt the
     * gradient). The dynamic branch passes matugen's own hex through untouched.
     */
    function hexOf(c) {
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    /**
     * The same conversion, uppercased, for the places that show a hex to the
     * user or write one into a flag: the accent, theme and font-colour editors
     * all display one and all store it uppercased.
     *
     * This lived as a private copy in each of those four surfaces. They were
     * byte-identical apart from the `toUpperCase`, which is exactly the kind of
     * duplication that hides a change: a fix to the conversion, or a decision
     * that it should round differently, had to be found four times and none of
     * the four would have failed if one were missed.
     */
    function hexUpper(c) {
        return hexOf(c).toUpperCase();
    }

    /** A typed `#rrggbb` as a color, or null when the text is not a colour. */
    function parseHex(text) {
        var s = String(text).trim();
        if (s.charAt(0) === "#") s = s.slice(1);
        return /^[0-9a-fA-F]{6}$/.test(s) ? Qt.color("#" + s) : null;
    }

    /**
     * Bright warm pop shared by the flame glow, charging glyphs, the recording
     * countdown, the unread inbox dot, the calendar's today cell and the held
     * power tile. The dynamic branch uses the wallpaper accent (Dyn.primary):
     * matugen's on-primary-container does not populate here and collapses the
     * token to black, while the accent always loads and contrasts the pill
     * surface. The static branches keep the fixed warm hex.
     */
    readonly property color onGlow: customAccent ? accent : (manual ? manualPal.primary : (dynamic ? Dyn.primary : "#ff9a64"))

    readonly property color verm:     customAccent ? Qt.darker(accent, 1.18) : (manual ? Qt.darker(manualPal.primary, 1.18) : (dynamic ? Qt.darker(Dyn.primary, 1.18) : "#c0442b"))
    readonly property color vermLit:  customAccent ? accent : (manual ? manualPal.primary : (dynamic ? Dyn.primary : "#e0563b"))
    readonly property color vermDeep: customAccent ? accentDeep : (manual ? manualPal.primary_container : (dynamic ? Dyn.primaryContainer : "#a3371f"))
    readonly property color cream:    customText ? customTextHex : (manual ? manualPal.cream : (dynamic ? Dyn.cream : (light ? "#2a241f" : "#ececec")))
    readonly property color bright:   customText ? customTextHex : (manual ? manualPal.bright : (dynamic ? Dyn.bright : (light ? "#1d1814" : "#ffffff")))
    readonly property color dim:      manual ? manualPal.dim : (dynamic ? Dyn.dim : (light ? "#6b635c" : "#8c8c8c"))
    readonly property color cardTop:  manual ? manualPal.surface_container_high : (dynamic ? Dyn.surfaceContainerHigh : (light ? "#f6f2ec" : "#171717"))
    readonly property color cardBot:  manual ? manualPal.surface_container_low : (dynamic ? Dyn.surfaceContainerLow : (light ? "#ece6df" : "#0c0c0c"))
    readonly property color border:   manual ? manualPal.outline_variant : (dynamic ? Dyn.outlineVariant : (light ? "#d9d1c8" : "#2b2b2b"))
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   manual ? manualPal.surface : (dynamic ? Dyn.surface : (light ? "#e9e3dc" : "#141414"))
    readonly property color subtle:   manual ? manualPal.subtle : (dynamic ? Dyn.subtle : (light ? "#5f574f" : "#a8a8a8"))
    readonly property color faint:    manual ? manualPal.faint : (dynamic ? Dyn.faint : (light ? "#8a8078" : "#6a6a6a"))
    readonly property color iconDim:  customText ? Qt.alpha(cream, 0.6) : (manual ? manualPal.icon_dim : (dynamic ? Dyn.iconDim : (light ? "#5a524b" : "#bdbdbd")))
    readonly property color hair:     Qt.alpha(cream, 0.13)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen:    Qt.alpha(cream, 0.07)
    readonly property color vermDim:   customAccent ? Qt.darker(accent, 1.5) : (manual ? Qt.darker(manualPal.primary, 1.5) : (dynamic ? Qt.darker(Dyn.primary, 1.5) : "#8a5440"))
    readonly property color vermDimDeep: customAccent ? Qt.darker(accent, 2.2) : (manual ? Qt.darker(manualPal.primary, 2.2) : (dynamic ? Qt.darker(Dyn.primary, 2.2) : "#5a3526"))
    readonly property color vermBurn:  customAccent ? Qt.darker(accentDeep, 1.1) : (manual ? Qt.darker(manualPal.primary_container, 1.1) : (dynamic ? Qt.darker(Dyn.primaryContainer, 1.1) : "#8a2c14"))
    readonly property color tickRest:  manual ? manualPal.tick_rest : (dynamic ? Dyn.tickRest : (light ? "#4a423c" : "#c2c2c2"))
    readonly property color threadBg:  Qt.alpha(cream, 0.13)
    readonly property color flameCore: customAccent ? Qt.lighter(accent, 1.03) : (dyn ? Qt.lighter(onGlow, 1.03) : "#ffd9c2")
    readonly property color flameGlow: customAccent ? accent : (dyn ? onGlow : "#ff9a64")

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render, so the dynamic branch passes
     * matugen's raw hex strings through untouched rather than any Qt.darker math,
     * and the manual branch passes the locally-computed PaletteHue hex strings.
     */
    readonly property string flameInk:   customAccent ? customHex : (manual ? manualPal.primary : (dynamic ? Dyn.primary : "#f0795a"))
    readonly property string flameEmber: customAccent ? hexOf(accentDeep) : (manual ? manualPal.primary_container : (dynamic ? Dyn.primaryContainer : "#7e2812"))
    readonly property string flameBurn:  customAccent ? hexOf(accentDeep) : (manual ? manualPal.primary_container : (dynamic ? Dyn.primaryContainer : "#8a2c14"))
    readonly property string flameTip:   customAccent ? hexOf(Qt.lighter(accent, 1.2)) : (manual ? manualPal.on_primary_container : (dynamic ? Dyn.onPrimaryContainer : "#ffb38a"))
    readonly property color todayWarm: customAccent ? accent : (dyn ? onGlow : "#ffb38a")
    readonly property color ghost:     manual ? manualPal.surface_container_highest : (dynamic ? Dyn.surfaceContainerHighest : (light ? "#e3ddd5" : "#242424"))
    readonly property color frameBg:      Qt.alpha(cream, 0.055)
    readonly property color frameBorder:  Qt.alpha(cream, 0.10)
    readonly property color creamMenu:     Qt.alpha(cream, 0.82)
    readonly property real shadowOpacity: 0.5
    /**
     * Snapshot of the system families, not a binding: Qt.fontFamilies() is not
     * notifiable, so a font dropped onto the pill re-registers through
     * refreshFonts() once its FontLoader is ready.
     */
    property var fontFamilies: Qt.fontFamilies()
    function refreshFonts() { fontFamilies = Qt.fontFamilies(); }
    readonly property string font: (Flags.uiFont.length > 0 && fontFamilies.indexOf(Flags.uiFont) >= 0) ? Flags.uiFont : "Inter"

    /**
     * Monospace face for the scratchpad's body editor, resolved the same way
     * fontJp is — a code-ish buffer wants columns that line up, and a note is
     * mostly prose pasted from somewhere that had columns. Falls back through
     * the usual suspects to the generic `monospace` family, which Qt always
     * resolves, so this is never empty.
     */
    readonly property var monoFamilies: ["JetBrains Mono", "Iosevka", "Berkeley Mono", "Fira Code", "Cascadia Code", "DejaVu Sans Mono"]
    readonly property string fontMono: {
        for (let i = 0; i < monoFamilies.length; i++) {
            if (fontFamilies.indexOf(monoFamilies[i]) >= 0)
                return monoFamilies[i];
        }
        return "monospace";
    }

    /**
     * Kanji face for the decorative glyphs, resolved against the installed
     * families rather than hardcoded. A missing name is not cosmetic here:
     * fontconfig answers "Zen Kaku Gothic New" with **Noto Sans CJK KR**, so
     * asking for a Japanese face and not having it silently renders the marks in
     * Korean glyph forms. Each entry is tried in order and the first one actually
     * present wins; the tail is a family that ships with noto-cjk, so the
     * fallback still resolves to a real face instead of a KR substitution.
     */
    readonly property var jpFamilies: ["Zen Kaku Gothic New", "Noto Sans CJK JP", "Noto Sans JP", "Source Han Sans JP"]
    readonly property string fontJp: {
        for (let i = 0; i < jpFamilies.length; i++) {
            if (fontFamilies.indexOf(jpFamilies[i]) >= 0)
                return jpFamilies[i];
        }
        return "Noto Sans CJK JP";
    }

    /**
     * One weight for every kanji glyph, and the reason is memory rather than
     * taste. A CJK family is a multi-weight .ttc collection, so each distinct
     * weight a Text asks for maps a SEPARATE face, and Qt's font database never
     * unmaps one it has loaded. The glyph sites were spread across Medium,
     * Regular, Bold and DemiBold, which kept three Noto Sans CJK faces resident
     * at once — 71.7 MiB — to draw ~25 single decorative marks. Pinning all of
     * them to Medium, the weight most already used, measures 26.9 MiB: the one
     * face they ask for, plus the one Qt's own CJK fallback opens when it has to
     * substitute a glyph into bold latin text. The marks are 15-16px, so the
     * weight difference is not readable anyway.
     */
    readonly property int fontJpWeight: Font.Medium

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
