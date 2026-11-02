import QtQuick
import "../Singletons"

/**
 * Mixer fader. Default is the vertical filament thread with a rising fill and a
 * flat tick; the Chaldea `pattern` versions draw one of the reference slider
 * tracks (comb teeth, slats diagonals, stipple dots, weave grid) with a blade
 * marker and an always-on mono readout.
 *
 * `horizontal` flips the control into a wide row — icon, label, track, value —
 * which is how the horizontal designs (slats, weave) lay the channels out.
 * `mirror` swaps the label and value ends. `readoutAbove`/`bigReadout` lift the
 * value over the vertical track for the gauge design (stipple). Hover targeting
 * is owned by the parent surface, which drives `focused`. Value is 0..1.
 */
Item {
    id: root

    property real s: 1
    property string icon: ""
    property real value: 0.5
    property string valueLabel: ""
    property string subLabel: ""
    property bool subPersistent: true
    property bool focused: false
    property bool muted: false
    property string pattern: ""
    property bool horizontal: false
    property bool mirror: false
    property bool readoutAbove: false
    property bool bigReadout: false

    signal moved(real v)
    signal committed(real v)
    signal iconClicked()

    readonly property bool lit: focused
    readonly property bool chaldea: pattern !== ""
    readonly property int thick: pattern === "weave" ? 14 : pattern === "stipple" ? 12 : pattern === "comb" ? 7 : 8
    readonly property real trackW: (chaldea ? thick : 22) * s
    readonly property real trackH: 86 * s
    readonly property real headH: (chaldea && !horizontal && readoutAbove) ? 18 * s : 0

    implicitWidth: horizontal ? 220 * s : 54 * s
    implicitHeight: horizontal ? 26 * s : headH + trackH + (subLabel.length ? 56 : 44) * s

    /**
     * Live tick centre in this fader's coordinates. The marker's y/x and
     * root's size are voided because mapToItem creates no QML dependency on the
     * source item's transform; without them the binding snapshots the marker
     * where it first rendered and the bead docks at a stale point.
     */
    readonly property point tickCenter: {
        void tick.y;
        void blade.y;
        void hBlade.x;
        void hBlade.y;
        void root.width;
        void root.height;
        if (root.horizontal)
            return hBlade.mapToItem(root, hBlade.width / 2, hBlade.height / 2);
        const m = root.chaldea ? blade : tick;
        return m.mapToItem(root, m.width / 2, m.height / 2);
    }

    /**
     * Nudge the value by a signed percentage (e.g. +1 / -1), clamped to 0..100%,
     * emitting `moved` and `committed` so live hardware updates on each step.
     */
    function step(deltaPct) {
        const v = Math.max(0, Math.min(1, root.value + deltaPct / 100));
        root.moved(v);
        root.committed(v);
    }

    /* ------------------------------------------------------------------ *
     * Vertical layout (default and the comb/stipple designs).
     * ------------------------------------------------------------------ */
    Item {
        id: vBox
        anchors.fill: parent
        visible: !root.horizontal

        Item {
            id: trackArea
            anchors.top: parent.top
            anchors.topMargin: root.headH
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.trackW
            height: root.trackH

            Rectangle {
                id: thread
                visible: !root.chaldea
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * root.s
                height: parent.height
                radius: width / 2
                color: Theme.threadBg

                Rectangle {
                    id: fill
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height * Math.max(0, Math.min(1, root.value))
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.muted ? Theme.vermDim : (root.lit ? Theme.vermLit : Theme.vermDim) }
                        GradientStop { position: 1.0; color: root.muted ? Theme.vermDimDeep : (root.lit ? Theme.vermBurn : Theme.vermDimDeep) }
                    }
                    Behavior on height { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast } }
                }
            }

            Rectangle {
                id: tick
                visible: !root.chaldea
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(0, Math.min(root.trackH - height,
                    (1 - Math.max(0, Math.min(1, root.value))) * root.trackH - height / 2))
                width: 11 * root.s
                height: 2.5 * root.s
                radius: 2 * root.s
                color: Theme.tickRest
                opacity: root.focused ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast } }
            }

            /** Chaldea style: the track body each pattern is drawn on. */
            Rectangle {
                visible: root.chaldea
                anchors.fill: parent
                color: Theme.tileBg
            }

            Canvas {
                id: patternCanvas
                visible: root.chaldea
                anchors.fill: parent
                renderStrategy: Canvas.Immediate
                property real level: root.value

                onLevelChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const w = width;
                    const h = height;
                    const lvl = Math.max(0, Math.min(1, level));
                    const fillTop = h * (1 - lvl);
                    ctx.reset();
                    ctx.clearRect(0, 0, w, h);

                    /** 60-degree stripes, as in the Chaldea slats reference. */
                    function slats(color, thick) {
                        const pitch = 6 * root.s / Math.sin(Math.PI / 3);
                        const stroke = thick / Math.sin(Math.PI / 3);
                        const off = h / Math.sqrt(3);
                        ctx.fillStyle = color;
                        for (let x = -pitch; x < w + off; x += pitch) {
                            ctx.beginPath();
                            ctx.moveTo(x, 0); ctx.lineTo(x + stroke, 0);
                            ctx.lineTo(x + stroke - off, h); ctx.lineTo(x - off, h);
                            ctx.closePath(); ctx.fill();
                        }
                    }

                    if (root.pattern === "comb") {
                        ctx.fillStyle = Theme.rgba(Theme.accent, 0.45);
                        for (let y = 0; y < fillTop; y += 7 * root.s)
                            ctx.fillRect(0, y, w, 2 * root.s);
                        ctx.fillStyle = Theme.hexOf(Theme.accent);
                        ctx.fillRect(0, fillTop, w, h - fillTop);
                    } else if (root.pattern === "slats") {
                        slats(Theme.rgba(Theme.cream, 0.30), 2 * root.s);
                        ctx.save();
                        ctx.beginPath(); ctx.rect(0, fillTop, w, h - fillTop); ctx.clip();
                        ctx.fillStyle = Theme.hexOf(Theme.cardBot); ctx.fillRect(0, fillTop, w, h - fillTop);
                        slats(Theme.hexOf(Theme.accent), 4 * root.s);
                        ctx.restore();
                    } else if (root.pattern === "stipple") {
                        ctx.fillStyle = Theme.rgba(Theme.accent, 0.5);
                        for (let x = 2 * root.s; x < w; x += 5 * root.s)
                            for (let y = 2 * root.s; y < fillTop; y += 5 * root.s) {
                                ctx.beginPath();
                                ctx.arc(x, y, 1 * root.s, 0, 7);
                                ctx.fill();
                            }
                        ctx.fillStyle = Theme.hexOf(Theme.accent);
                        ctx.fillRect(0, fillTop, w, h - fillTop);
                    } else {
                        ctx.strokeStyle = Theme.rgba(Theme.accent, 0.6);
                        ctx.lineWidth = 0.7 * root.s;
                        ctx.beginPath();
                        for (let x = 2.5 * root.s; x < w; x += 5 * root.s) {
                            ctx.moveTo(x, 0); ctx.lineTo(x, fillTop);
                        }
                        for (let y = 2.5 * root.s; y < fillTop; y += 5 * root.s) {
                            ctx.moveTo(0, y); ctx.lineTo(w, y);
                        }
                        ctx.stroke();
                        ctx.fillStyle = Theme.hexOf(Theme.accent);
                        ctx.fillRect(0, fillTop, w, h - fillTop);
                    }
                }
            }

            /** Chaldea style: the blade marker, shaped per design. */
            Item {
                id: blade
                visible: root.chaldea
                width: (root.pattern === "weave" ? 30 : root.pattern === "stipple" ? 20 : 18) * root.s
                height: (root.pattern === "weave" ? 3 : root.pattern === "stipple" ? 5 : root.pattern === "slats" ? 2 : 3) * root.s
                x: (trackArea.width - width) / 2
                y: Math.max(0, Math.min(trackArea.height - height,
                    (1 - Math.max(0, Math.min(1, root.value))) * trackArea.height - height / 2))
                Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: Motion.fast } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2 * root.s
                    color: Theme.cardBot
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.muted ? Theme.faint : Theme.cream
                }

                Rectangle {
                    visible: root.pattern === "slats"
                    anchors.centerIn: parent
                    width: 2 * root.s
                    height: 8 * root.s
                    color: root.muted ? Theme.faint : Theme.cream
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -10 * root.s
                preventStealing: true
                function setFromY(my) {
                    const v = 1 - Math.max(0, Math.min(1, (my - 10 * root.s) / root.trackH));
                    root.moved(v);
                }
                onPressed: (e) => setFromY(e.y)
                onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
                onReleased: root.committed(root.value)
            }
        }

        Text {
            id: readout
            anchors.top: root.readoutAbove ? undefined : trackArea.bottom
            anchors.bottom: root.readoutAbove ? trackArea.top : undefined
            anchors.topMargin: 7 * root.s
            anchors.bottomMargin: 5 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueLabel
            color: root.chaldea
                ? (root.muted ? Theme.faint : (root.lit ? Theme.cream : Theme.subtle))
                : (root.muted ? Theme.dim : (root.lit ? Theme.cream : Theme.dim))
            opacity: root.chaldea || root.bigReadout ? 1 : (root.lit ? 1 : 0)
            font.family: root.chaldea ? Theme.fontMono : Theme.font
            font.pixelSize: (root.bigReadout ? 12 : 9) * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        Item {
            id: iconBox
            anchors.top: root.readoutAbove ? trackArea.bottom : readout.bottom
            anchors.topMargin: 3 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: 18 * root.s
            height: 18 * root.s

            GlyphIcon {
                anchors.fill: parent
                name: root.icon
                color: root.muted ? Theme.dim : (root.lit ? Theme.cream : Theme.iconDim)
                stroke: 1.7
            }
        }

        Text {
            id: caption
            visible: root.subLabel.length > 0
            opacity: root.subPersistent || root.lit ? 1 : 0
            anchors.top: iconBox.bottom
            anchors.topMargin: 1 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.subLabel
            color: root.chaldea
                ? (root.lit ? Theme.cream : Theme.subtle)
                : (root.lit ? Theme.cream : Theme.faint)
            font.family: root.chaldea ? Theme.fontMono : Theme.font
            font.pixelSize: 9 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: (root.chaldea ? 0.5 : 0.3) * root.s
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }

    /* ------------------------------------------------------------------ *
     * Horizontal layout (slats and weave designs): one wide channel row.
     * ------------------------------------------------------------------ */
    Item {
        id: hBox
        anchors.fill: parent
        visible: root.horizontal

        GlyphIcon {
            id: hIcon
            width: 13 * root.s
            height: 13 * root.s
            anchors.verticalCenter: parent.verticalCenter
            x: root.mirror ? parent.width - width : 0
            name: root.icon
            color: root.muted ? Theme.faint : (root.lit ? Theme.cream : Theme.subtle)
            stroke: 1.7

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4 * root.s
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        Text {
            id: hCaption
            anchors.verticalCenter: parent.verticalCenter
            x: root.mirror ? parent.width - 78 * root.s : 19 * root.s
            width: 60 * root.s
            horizontalAlignment: root.mirror ? Text.AlignRight : Text.AlignLeft
            text: root.subLabel
            elide: Text.ElideRight
            color: root.lit ? Theme.cream : Theme.subtle
            font.family: Theme.fontMono
            font.pixelSize: 8.5 * root.s
            font.letterSpacing: 0.5 * root.s
        }

        Text {
            id: hReadout
            anchors.verticalCenter: parent.verticalCenter
            x: root.mirror ? 0 : parent.width - 36 * root.s
            width: 34 * root.s
            horizontalAlignment: root.mirror ? Text.AlignLeft : Text.AlignRight
            text: root.valueLabel
            color: root.muted ? Theme.faint : (root.lit ? Theme.cream : Theme.subtle)
            font.family: Theme.fontMono
            font.pixelSize: (root.bigReadout ? 12 : 9) * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Item {
            id: hTrack
            anchors.verticalCenter: parent.verticalCenter
            x: root.mirror ? 38 * root.s : 82 * root.s
            width: Math.max(0, parent.width - (root.mirror ? 120 : 122) * root.s)
            height: (root.chaldea ? root.thick : 3) * root.s

            Rectangle {
                anchors.fill: parent
                color: Theme.tileBg
            }

            Canvas {
                id: hCanvas
                visible: root.chaldea
                anchors.fill: parent
                renderStrategy: Canvas.Immediate
                property real level: root.value

                onLevelChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    const w = width;
                    const h = height;
                    const lvl = Math.max(0, Math.min(1, level));
                    const fillX = w * lvl;
                    ctx.reset();
                    ctx.clearRect(0, 0, w, h);

                    function slats(color, thick) {
                        const pitch = 6 * root.s / Math.sin(Math.PI / 3);
                        const stroke = thick / Math.sin(Math.PI / 3);
                        const off = h / Math.sqrt(3);
                        ctx.fillStyle = color;
                        for (let x = -off; x < w + pitch; x += pitch) {
                            ctx.beginPath();
                            ctx.moveTo(x, 0); ctx.lineTo(x + off, h);
                            ctx.lineTo(x + off + stroke, h); ctx.lineTo(x + stroke, 0);
                            ctx.closePath(); ctx.fill();
                        }
                    }

                    if (root.pattern === "slats") {
                        slats(Theme.rgba(Theme.cream, 0.30), 2 * root.s);
                        ctx.save();
                        ctx.beginPath(); ctx.rect(0, 0, fillX, h); ctx.clip();
                        ctx.fillStyle = Theme.hexOf(Theme.cardBot); ctx.fillRect(0, 0, fillX, h);
                        slats(Theme.hexOf(Theme.accent), 4 * root.s);
                        ctx.restore();
                    } else {
                        ctx.strokeStyle = Theme.rgba(Theme.accent, 0.6);
                        ctx.lineWidth = 0.7 * root.s;
                        ctx.beginPath();
                        for (let x = 2.5 * root.s; x < w; x += 5 * root.s) {
                            ctx.moveTo(x, 0); ctx.lineTo(x, h);
                        }
                        for (let y = 2.5 * root.s; y < h; y += 5 * root.s) {
                            ctx.moveTo(0, y); ctx.lineTo(w, y);
                        }
                        ctx.stroke();
                        ctx.fillStyle = Theme.hexOf(Theme.accent);
                        ctx.fillRect(0, 0, fillX, h);
                    }
                }
            }

            Item {
                id: hBlade
                visible: root.chaldea
                width: (root.pattern === "weave" ? 3 : 2) * root.s
                height: (root.pattern === "weave" ? 20 : 18) * root.s
                x: Math.max(0, Math.min(hTrack.width - width, hTrack.width * Math.max(0, Math.min(1, root.value)) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                Behavior on x { enabled: !hDrag.pressed; NumberAnimation { duration: Motion.fast } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2 * root.s
                    color: Theme.cardBot
                }

                Rectangle {
                    anchors.fill: parent
                    color: root.muted ? Theme.faint : Theme.cream
                }

                Rectangle {
                    visible: root.pattern === "slats"
                    anchors.centerIn: parent
                    width: 8 * root.s
                    height: 2 * root.s
                    color: root.muted ? Theme.faint : Theme.cream
                }
            }

            MouseArea {
                id: hDrag
                anchors.fill: parent
                anchors.topMargin: -10 * root.s
                anchors.bottomMargin: -10 * root.s
                preventStealing: true
                function setFromX(mx) {
                    root.moved(Math.max(0, Math.min(1, mx / Math.max(1, hTrack.width))));
                }
                onPressed: (e) => setFromX(e.x)
                onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
                onReleased: root.committed(root.value)
            }
        }
    }
}
