import QtQuick

/**
 * Waybar "rail" chrome: two separate notches, one flush to the left screen
 * edge and one to the right, both attached to the top edge. Each inner edge
 * sweeps out and blends into the top edge (a "swoosh") instead of meeting it
 * at a hard corner, so the modules read as flowing out of the top of the
 * screen. There is no connector strip between them; the centre stays open for
 * the floating clock island.
 */
Canvas {
    id: root

    property real leftWidth: 240
    property real rightWidth: 240
    property real radius: 14
    property real swoosh: 28
    property color color: "black"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onSwooshChanged: requestPaint()
    onColorChanged: requestPaint()

    /**
     * One notch, flush to the top and its own screen edge. `l` is its inner
     * edge; `swoosh` is how far the top edge flares past that edge before
     * curving back down into it.
     */
    function notch(ctx, l, h) {
        const r = root.radius
        const sw = Math.max(0, Math.min(root.swoosh, l - r, h - r))

        ctx.beginPath()
        ctx.moveTo(0, h)
        ctx.lineTo(l - r, h)
        ctx.arcTo(l, h, l, h - r, r)            // bottom-inner rounded corner
        ctx.lineTo(l, sw)
        ctx.quadraticCurveTo(l, 0, l + sw, 0)   // sweep out into the top edge
        ctx.lineTo(0, 0)
        ctx.lineTo(0, h)
        ctx.closePath()
        ctx.fill()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        const w = width
        const h = height
        const l = Math.min(root.leftWidth, w * 0.42)
        const rightStart = w - Math.min(root.rightWidth, w * 0.42)

        ctx.fillStyle = root.color

        root.notch(ctx, l, h)

        ctx.save()
        ctx.translate(w, 0)
        ctx.scale(-1, 1)
        root.notch(ctx, w - rightStart, h)
        ctx.restore()
    }
}
