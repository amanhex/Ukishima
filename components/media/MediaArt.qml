pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import ".."
import "../../Singletons"

/**
 * Album artwork shared by the Chaldea-style media designs.
 *
 * `host` is the Media surface: cover source, decode latch and playing state all
 * come from it, so every design shows the same cover and the same fallback.
 * `matrix` swaps the bitmap for the glyph-matrix render (Chaldea's Matrix
 * design) and `lineColor` lets each design pick its frame weight.
 */
Item {
    id: art

    property var host: null
    property color lineColor: Theme.border
    property bool matrix: false
    readonly property real s: art.host ? art.host.s : 1
    readonly property bool ready: art.host ? art.host.everReady : false

    ClippingRectangle {
        anchors.fill: parent
        color: Theme.tileBg
        border.width: 1
        border.color: art.lineColor

        Image {
            anchors.fill: parent
            visible: !art.matrix
            source: art.host ? art.host.coverSource : ""
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            retainWhileLoading: true
            cache: String(source).indexOf("file:") !== 0
            onStatusChanged: {
                if (!art.host)
                    return;
                if (status === Image.Ready)
                    art.host.everReady = true;
                else if (status === Image.Error && source !== "")
                    art.host.everReady = false;
            }
        }
    }

    /** No cover yet: a tiny equalizer while playing, a note glyph otherwise. */
    Item {
        anchors.fill: parent
        visible: !art.ready && !art.matrix

        Row {
            id: eq
            anchors.centerIn: parent
            spacing: 2 * art.s
            visible: art.host ? art.host.playing : false

            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: 2 * art.s
                    height: 5 * art.s
                    color: Theme.accent

                    SequentialAnimation on height {
                        running: eq.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: (5 + index * 2) * art.s; duration: 360 + index * 80; easing.type: Easing.InOutSine }
                        NumberAnimation { to: (10 - index * 2) * art.s; duration: 400 + index * 80; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        GlyphIcon {
            anchors.centerIn: parent
            width: Math.min(18 * art.s, parent.width * 0.4)
            height: width
            name: "music"
            color: Theme.iconDim
            visible: !(art.host && art.host.playing)
        }
    }

    /** Matrix design: the cover reduced to a 32x32 glyph grid. */
    Canvas {
        id: glyphs
        anchors.fill: parent
        visible: art.matrix
        renderStrategy: Canvas.Immediate

        property string loadedSource: ""
        property url source: art.host ? art.host.coverSource : ""

        function refresh() {
            var src = String(glyphs.source || "");
            if (glyphs.loadedSource && glyphs.loadedSource !== src)
                unloadImage(glyphs.loadedSource);
            glyphs.loadedSource = src;
            if (src)
                loadImage(src);
            requestPaint();
        }

        onSourceChanged: refresh()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) refresh()
        onImageLoaded: requestPaint()
        Component.onCompleted: refresh()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const size = Math.max(1, Math.floor(Math.min(width, height)));
            ctx.fillStyle = Theme.hexOf(Theme.cardBot);
            ctx.fillRect(0, 0, width, height);

            const src = glyphs.loadedSource;
            if (size < 4 || !src || !isImageLoaded(src) || isImageError(src)) {
                ctx.textAlign = "center";
                ctx.fillStyle = Theme.hexOf(Theme.iconDim);
                ctx.font = Math.max(9, size * 0.3) + "px monospace";
                ctx.fillText(art.host ? art.host.trackNo : "--", size / 2, size * 0.55);
                ctx.fillStyle = Theme.hexOf(Theme.faint);
                ctx.font = Math.max(5, size * 0.08) + "px monospace";
                ctx.fillText("NO COVER ART", size / 2, size * 0.7);
                return;
            }

            ctx.drawImage(src, 0, 0, size, size);
            const pixels = ctx.getImageData(0, 0, size, size);
            ctx.fillStyle = Theme.hexOf(Theme.cardBot);
            ctx.fillRect(0, 0, width, height);
            ctx.font = Math.max(3, (size / 32) * 0.9) + "px monospace";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            const glyphSet = " .·:+x*#@";
            for (let row = 0; row < 32; row++) {
                for (let col = 0; col < 32; col++) {
                    const x = (col + 0.5) * size / 32;
                    const y = (row + 0.5) * size / 32;
                    const p = (Math.floor(y) * size + Math.floor(x)) * 4;
                    const r = pixels.data[p];
                    const g = pixels.data[p + 1];
                    const b = pixels.data[p + 2];
                    const tone = Math.min(1, Math.max(0, ((r * 0.3 + g * 0.59 + b * 0.11) / 255 - 0.025) / 0.47));
                    const k = Math.min(8, Math.floor(Math.pow(tone, 0.65) * 8));
                    ctx.fillStyle = (r > g * 1.45 && r > 65) ? Theme.hexOf(Theme.vermLit) : Theme.rgba(Theme.cream, 0.22 + Math.sqrt(tone) * 0.72);
                    ctx.fillText(glyphSet[k], x, y);
                }
            }
        }
    }
}
