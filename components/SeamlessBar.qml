import QtQuick

/**
 * Waybar "rail" chrome, ported from the SeamlessBarShape in the reference
 * dotfiles (SaratAngajalaoffl/dotfiles-quickshell).
 *
 * One Canvas paints a thin strip along the top edge plus the left and right
 * module notches. The notches are flush to the screen edges and to the top,
 * their inner top corner sweeps into the strip, and their bottom inner corner
 * is rounded — so the strip joins the pieces into a single object. The centre
 * is left open for the floating clock island.
 */
Canvas {
    id: root

    property real leftWidth: 240
    property real rightWidth: 240
    property real radius: 14
    property real strip: 5
    property color color: "black"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onStripChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const w = width
        const h = height
        const r = root.radius
        const b = root.strip
        const l = Math.min(root.leftWidth, w * 0.42)
        const rightStart = w - Math.min(root.rightWidth, w * 0.42)

        ctx.beginPath()
        ctx.fillStyle = root.color

        // Left notch: flush to the left edge, top-inner corner into the strip.
        ctx.moveTo(0, h)
        ctx.lineTo(l - r, h)
        ctx.arcTo(l, h, l, h - r, r)
        ctx.lineTo(l, b + r)
        ctx.arcTo(l, b, l + r, b, r)

        // Thin connecting strip across the gap.
        ctx.lineTo(rightStart - r, b)

        // Right notch, mirrored.
        ctx.arcTo(rightStart, b, rightStart, b + r, r)
        ctx.lineTo(rightStart, h - r)
        ctx.arcTo(rightStart, h, rightStart + r, h, r)
        ctx.lineTo(w, h)

        // Close over the top edge: the strip runs the full width.
        ctx.lineTo(w, 0)
        ctx.lineTo(0, 0)
        ctx.lineTo(0, h)
        ctx.fill()
    }
}