import QtQuick
import QtQuick.Effects
import "GlyphArt.js" as Art

/**
 * The compound glyph from the Chaldea editorial/print studies, drawn from the
 * shared 0BSD rules. `phase` follows how many characters are in the password,
 * so the mark subdivides as you type and reverses on backspace.
 *
 * The lockscreen cannot import Theme (separate process), so the two colours in
 * GlyphArt.js are the lock's own cream/red pair.
 */
Item {
    id: root

    property real phase: 0
    property real emphasis: 100
    property var host: null
    readonly property bool isSharpCapture: root.host ? (root.host.background === "capture" && root.host.blurMax <= 16) : false
    readonly property real effectiveGroundOpacity: isSharpCapture ? 0.88 : root.groundOpacity
    //* Readable plate behind the mark. The glyph is thin cream/red strokes,
    //* which vanish over a sharp capture or a busy wallpaper; designs that
    //* already sit on their own panel (Phase's faint backdrop, Reactive's
    //* #090909 tile) turn it off.
    property bool showGround: true
    property color ground: "#090909"
    property real groundOpacity: 0.5

    implicitWidth: 252
    implicitHeight: 252
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "Compound glyph"

    onPhaseChanged: drawing.requestPaint()
    onWidthChanged: drawing.requestPaint()
    onHeightChanged: drawing.requestPaint()

    Rectangle {
        anchors.fill: parent
        visible: root.showGround || root.isSharpCapture
        radius: 2
        color: root.isSharpCapture ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(root.ground.r, root.ground.g, root.ground.b, root.groundOpacity)
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: root.isSharpCapture
            blur: 1
        }
    }

    Canvas {
        id: drawing

        width: 504
        height: 504
        scale: Math.min(root.width, root.height) / 504
        transformOrigin: Item.TopLeft

        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.setTransform(2, 0, 0, 2, 0, 0);
            context.lineCap = "butt";
            context.lineJoin = "miter";
            for (const mark of Art.glyphMarks(root.phase, root.emphasis)) {
                context.globalAlpha = mark.alpha;
                context.strokeStyle = mark.c;
                context.lineWidth = mark.w;
                context.beginPath();
                mark.points.forEach((point, index) => {
                    if (index)
                        context.lineTo(point[0], point[1]);
                    else
                        context.moveTo(point[0], point[1]);
                });
                context.stroke();
            }
            context.globalAlpha = 1;
        }
    }
}