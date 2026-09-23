pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * LiquidGlass — the material behind the settings' "Transparency mode". A translucent, palette-tinted slab.
 *
 * The glass is a *surface* material, not a backdrop filter: the slab keeps the
 * shell window's transparent background, so what is behind the shell (the
 * desktop, the wallpaper) glows through it at `styleTint * Flags.pillOpacity`
 * translucency. No blur, no frosted/milky whitening, no noise, no shaders, no
 * wallpaper dependency — the fill stays palette-true, so it always matches the
 * theme even as it lets the desktop read through.
 *
 * The material owns: the translucent gradient tint (with a whisper of the
 * wallpaper accent on dynamic palettes), the hairline edge, the top sheen, the
 * optional readability `veil` for copy areas, and quiet hover/pressed/active
 * state feedback. Nothing runs per frame: the fill is a plain gradient whose
 * colours only recompute when a material input changes, with no timers, layers
 * or shaders involved.
 *
 * With `Flags.glass` off the material falls back to the exact legacy look
 * (flat gradient at `legacyOpacity`, plain `borderColor`, `Theme.sheen`), so
 * the setting is a true reversal, not a restyle.
 */
Rectangle {
    id: glass

    /// "regular" (rest/hover/expanded pill) or "clear" (media / floating cards).
    property string style: "regular"
    /// Explicit tint alpha (0.35..0.95). -1 derives from `style`.
    property real materialOpacity: -1
    /// Fill alpha when not glassy — mirrors the legacy gradient exactly. The
    /// pill body and OSD pass `Flags.pillOpacity`, Media passes 1 (opaque card).
    property real legacyOpacity: 1
    /// Palette accent transmission weight: how strongly Theme.onGlow (the
    /// wallpaper's Dyn.primary on dynamic palettes) tints the fill. 0 = none.
    property real accent: 0.06
    /// Top-sheen intensity multiplier.
    property real sheenScale: 1
    /// Inner darkening for copy contrast over bright backdrops (0 = none).
    /// The baseline each surface chooses; the user's Text-visibility setting
    /// (`Flags.glassText`, 0..1) lifts it further when glass is on.
    property real veil: 0
    /// Hairline colour; the legacy edge.
    property color borderColor: Theme.border
    /// Adaptive state feedback: hover lifts translucency and sheen, pressed
    /// densifies the fill and dims the sheen, active adds a touch more accent.
    property bool hovered: false
    property bool pressed: false
    property bool active: false

    /// Master switch: the glass material is on.
    readonly property bool glassy: Flags.glass

    /// The veil actually painted when glassy: the surface baseline plus the
    /// user's text-visibility boost (up to +0.12), capped so it never becomes a
    /// solid block. Off with glass off, so legacy text sits on the exact
    /// legacy fill. `(Flags.glassText || 0)` guards a flags file that predates
    /// the key (Quickshell's JsonAdapter serializes absent keys as null).
    readonly property real veilAlpha: glass.glassy
        ? Math.min(0.3, glass.veil + 0.12 * (Flags.glassText || 0))
        : 0

    readonly property real styleTint: glass.materialOpacity >= 0 ? glass.materialOpacity
        : (glass.style === "clear" ? 0.62 : 0.78)

    readonly property real tintAlpha: {
        if (!glass.glassy)
            return glass.legacyOpacity;
        var a = glass.styleTint * Flags.pillOpacity;
        if (glass.hovered) a += 0.05;
        if (glass.pressed) a -= 0.06;
        if (glass.active)  a += 0.02;
        return Math.max(0.35, Math.min(0.95, a));
    }

    /// RGB mix toward `b`, preserving `a`'s alpha. Used for tint and edge tints.
    function blend(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a);
    }

    /// The palette accent this slab transmits; on dynamic palettes that is the
    /// wallpaper's dominant hue bleeding through the fill.
    readonly property color accentColor: Theme.onGlow

    readonly property color tintTop: glass.glassy
        ? Qt.alpha(blend(Theme.cardTop, accentColor, accent * (glass.active ? 1.3 : 1)), tintAlpha)
        : Qt.alpha(Theme.cardTop, tintAlpha)
    readonly property color tintBot: glass.glassy
        ? Qt.alpha(blend(Theme.cardBot, accentColor, accent * 0.6), tintAlpha)
        : Qt.alpha(Theme.cardBot, tintAlpha)

    border.width: 1
    border.color: glass.borderColor

    gradient: Gradient {
        GradientStop { position: 0.0; color: glass.tintTop }
        GradientStop { position: 1.0; color: glass.tintBot }
    }

    /**
     * Readability veil — an extra drop of darkness on copy areas so pale text
     * keeps contrast on bright wallpapers. A plain flat alpha, no filter. The
     * alpha blends the surface's own baseline with the user's Text-visibility
     * setting, so it stays theme-consistent while the slider actually moves it.
     * Mirrors the slab's radii so it never pokes square corners past the
     * rounded silhouette (with the strip's square top that edge stays flush).
     */
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        topLeftRadius: parent.topLeftRadius
        topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius
        visible: glass.glassy && glass.veilAlpha > 0
        color: Qt.rgba(0, 0, 0, glass.veilAlpha)
    }

    /**
     * Top sheen — the edge light. Legacy keeps the plain Theme.sheen hairline;
     * glassy draws none: over a translucent fill a lighter 1px line under the
     * border reads as a bright rim, so transparency mode keeps only the plain
     * hairline. Press feedback is likewise skipped when glassy.
     */
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: parent.radius * 0.6
        anchors.rightMargin: parent.radius * 0.6
        height: 1
        color: glass.glassy ? "transparent" : Theme.sheen
    }
}