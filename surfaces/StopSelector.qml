pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../Singletons"
import "../components"

/**
 * The transient centred picker. A faint scrim drops over the whole screen and a
 * card sits in the middle; picking an option closes it on the spot, and a
 * press on the scrim closes it without choosing. It draws the `Selector`
 * singleton's state and is hosted by the overlay window, so the page that
 * opened it never has to grow to hold it.
 *
 * What the card is choosing is always stated at the top: the centring costs the
 * context the old inline menu borrowed from the row it hung under, and the title
 * pays it back. Every choice then reads as one thing — the applied value in the
 * flame ink with a tick, the option the pointer or keyboard sits on wearing the
 * card's only fill — so two options can never both look chosen, and that is
 * structural: no option paints a fill of its own. The type is the same measure
 * as the settings rows that open them (a 12.5px label, a 26px glyph), so the card
 * reads as that page turned up, not as a cramped menu bolted to the middle of the
 * screen. What the rows open is a *surface*, so the card is lit from the top
 * like the rest of the shell's glass, the title band closes on the accent rather
 * than a grey hairline, each glyph sits on a raised plate, and the key hints wear
 * the key caps they name.
 *
 * The card is paper, and things happen to the paper:
 *
 *  - the fill under the cursor is a single rectangle that *travels* between
 *    options (tile to tile, chip to chip), so the eye follows the highlight
 *    instead of re-reading the list;
 *  - a dot grid in the paper lights up around whatever is being pointed at —
 *    the pointer when it is over the card, the keyboard's line when it is not;
 *  - one pass of light crosses the paper as the card lands, so the card reads as
 *    placed down rather than faded in.
 *
 * Short lists — and in this shell nearly every list is two to four options — are
 * tiles in a single row, under a footer that names the keys, this being the one
 * surface in the shell driven entirely from the keyboard. One row rather than a
 * grid, so the reading order is the walk order and every arrow key means the
 * same thing. Options too long to tile become wrapping chips under the card's
 * width cap.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    visible: root.active || opacity > 0
    opacity: root.active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

    onActiveChanged: {
        card.ready = false;
        card.pointerSeen = false;
        if (active) {
            readyTimer.restart();
            sweepRun.restart();
        }
    }

    /** Above this many options a single row of tiles would be too many narrow
     * columns, so the chips, which wrap, read better. */
    readonly property int tileLimit: 4
    readonly property bool tiles: Selector.options.length <= root.tileLimit

    /** One row of tiles, never a grid: the walk order is then the reading order,
     * so all four arrow keys keep meaning the same thing. */
    readonly property int tileCols: Math.max(1, Selector.options.length)
    readonly property real tileGap: 8 * root.s

    /** How wide a tile wants to be. Four across only clears the card's width cap
     * at a narrower measure than two or three across do. Tiles stretch to fill
     * the row, so this is a floor, not the final width. */
    readonly property real tileW: Selector.options.length >= 4 ? 96 * root.s : 130 * root.s

    /**
     * Widths are read from the delegates' own `naturalW`, not from a
     * positioner's `implicitWidth`. A positioner only refreshes that during a
     * polish pass, so a picker that opens with its options in hand would measure
     * zero and sit at its floor.
     */
    readonly property real tileRowW: root.tileCols * root.tileW + (root.tileCols - 1) * root.tileGap

    /** Bumped whenever the chips add, remove or resize, so the width sum below
     * re-reads: `itemAt()` is not a tracked dependency. */
    property int optionRev: 0

    readonly property real chipsW: {
        root.optionRev;
        var n = chipRep.count;
        if (n === 0)
            return 0;
        var gap = 8 * root.s;
        var total = gap * (n - 1);
        for (var i = 0; i < n; i++) {
            var it = chipRep.itemAt(i);
            if (it)
                total += it.naturalW;
        }
        return total;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.04)

        MouseArea {
            anchors.fill: parent
            enabled: root.active
            acceptedButtons: Qt.AllButtons
            onClicked: Selector.close()
        }
    }

    Rectangle {
        id: card

        objectName: "card"

        readonly property real pad: 16 * root.s
        readonly property real maxW: Math.min(root.width - 80 * root.s, 440 * root.s)
        readonly property real optionsW: root.tiles ? root.tileRowW : root.chipsW
        readonly property real naturalW: Math.max(Math.max(header.visible ? header.implicitWidth : 0, optionsW),
                                                  hintRow.implicitWidth) + 2 * pad

        /** One tile's measure. Tall enough that a 26px glyph over a label sits
         * in it with air, and that a bare number still reads as a panel. */
        readonly property real tileH: 94 * root.s

        /** The paper's weave. */
        readonly property real gridStep: 26 * root.s
        readonly property int gridCols: Math.max(1, Math.floor((width - 2 * pad) / gridStep) + 1)
        readonly property int gridRows: Math.max(1, Math.floor((height - 2 * pad) / gridStep) + 1)

        /** Where the light is, in card coordinates: the pointer while it is over
         * the card, otherwise the centre of the line the keyboard sits on, so
         * the paper answers the keyboard too. */
        property real px: 0
        property real py: 0
        property bool pointerIn: false

        /** Whether the pointer has even told us where it is. The card can open
         * with the pointer already sitting on it (and over padding, where no
         * option fires), so until a hit area reports a position the light stays
         * on the keyboard's line rather than jumping to the top corner. */
        property bool pointerSeen: false

        /** The line the keyboard sits on, as the card sees it. The sums are the
         * whole point: each term is a property read, so the light re-aims after
         * a keyboard move. `mapToItem` would be shorter and silently wrong — it
         * does its reading in C++, which the binding engine does not capture. */
        function cursorCentre() {
            const c = root.tiles ? tileCursor : chipCursor;
            const stage = root.tiles ? tileStage : chipStage;
            return Qt.point(col.x + stage.x + c.x + c.width / 2,
                            card.cursorTop() + card.cursorH() / 2);
        }

        /** The travelling line's own top and height in card coordinates. The
         * light in the paper rides this line, so it is asked for the same way
         * wherever it is needed. */
        function cursorTop() {
            const c = root.tiles ? tileCursor : chipCursor;
            const stage = root.tiles ? tileStage : chipStage;
            return col.y + stage.y + c.y;
        }

        function cursorH() {
            return root.tiles ? tileCursor.height : chipCursor.height;
        }

        readonly property point light: (card.pointerIn && card.pointerSeen)
                                       ? Qt.point(card.px, card.py) : cursorCentre()

        /** The pointer, in card coordinates, as reported by whichever option it
         * is over. A `HoverHandler` only ever tells this shell *that* something
         * is hovered (`hovered`), never where; the option hit areas are already
         * the thing that moves the cursor, so they carry the position too. */
        function pointAt(hit) {
            const p = hit.mapToItem(card, hit.mouseX, hit.mouseY);
            card.px = p.x;
            card.py = p.y;
            card.pointerSeen = true;
        }

        /** The travelling pill only starts moving once the card is up: on open
         * the highlight is simply already on the value, no slide across the
         * list. */
        property bool ready: false

        anchors.centerIn: parent
        width: Math.max(248 * root.s, Math.min(maxW, naturalW))
        height: col.implicitHeight + 2 * pad
        radius: 16 * root.s
        color: Theme.cardBot

        /** Lit from the top, so the card reads as a pane of the shell's glass
         * rather than a flat rectangle with a hairline round it. */
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        border.width: 1
        border.color: Theme.border
        scale: root.active ? 1 : 0.96

        Behavior on scale {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 6 * root.s
        }

        HoverHandler {
            id: cardHover

            onHoveredChanged: {
                card.pointerIn = cardHover.hovered;
                if (!cardHover.hovered)
                    card.pointerSeen = false; // a stale spot is worse than none
            }
        }

        /** For looks: the weave breathes while the card is up, so the paper is
         * alive between keypresses. It only ever dips — the peak is the sheen it
         * already was, never a texture over the words. */
        property real twinkle: 1

        SequentialAnimation on twinkle {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.62; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.62; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
        }

        /** The dot grid: invisible except where the light is. Peak opacity is
         * low on purpose — it is a sheen on the paper, never a texture over the
         * words. */
        Item {
            id: paper

            anchors.fill: parent
            clip: true

            /** The rim: the paper catches the light along its top edge, and the
             * light runs out before the corners, which are round. */
            Rectangle {
                width: parent.width - 30 * root.s
                height: 1
                y: 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(Theme.cream, 0.16) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            /** Registration marks in the four corners: for looks, and they frame
             * the paper without adding a second border round the card. */
            Repeater {
                model: 4

                Item {
                    required property int index

                    readonly property real mark: 11 * root.s
                    readonly property real arm: 9 * root.s
                    readonly property bool isRight: (index % 2) === 1
                    readonly property bool isLow: index > 1

                    x: isRight ? card.width - mark : mark
                    y: isLow ? card.height - mark : mark

                    Rectangle {
                        width: arm
                        height: 1
                        radius: 0.5
                        x: isRight ? -width : 0
                        y: isLow ? -height : 0
                        color: Qt.alpha(Theme.vermLit, 0.30)
                    }

                    Rectangle {
                        width: 1
                        height: arm
                        radius: 0.5
                        x: isRight ? -width : 0
                        y: isLow ? -height : 0
                        color: Qt.alpha(Theme.vermLit, 0.30)
                    }
                }
            }

            Repeater {
                model: card.gridCols * card.gridRows

                Rectangle {
                    id: dot

                    required property int index

                    readonly property real gx: card.pad + (dot.index % card.gridCols) * card.gridStep
                    readonly property real gy: card.pad + Math.floor(dot.index / card.gridCols) * card.gridStep

                    x: dot.gx - width / 2
                    y: dot.gy - height / 2
                    width: 1.7 * root.s
                    height: width
                    radius: width / 2
                    color: Theme.vermLit
                    opacity: {
                        const dx = dot.gx - card.light.x;
                        const dy = dot.gy - card.light.y;
                        const d = Math.sqrt(dx * dx + dy * dy);
                        const t = Math.max(0, 1 - d / (96 * root.s));
                        return t * t * 0.34 * card.twinkle;
                    }
                }
            }

            /** One pass of light across the paper as the card lands: the card is
             * placed down, not faded in. Runs on every open (`onActiveChanged`),
             * since this instance is built once and lives for the session. */
            Rectangle {
                id: sweep

                property real progress: 0

                y: 0
                width: card.width * 0.34
                height: paper.height
                x: -width + sweep.progress * (card.width + width)
                opacity: Math.sin(sweep.progress * Math.PI) * 0.9
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.alpha(Theme.cream, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Column {
            id: col

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: card.pad
            spacing: 11 * root.s

            Text {
                id: header

                visible: Selector.title.length > 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Selector.title
                color: Theme.creamMenu
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.4 * root.s
            }

            /** The band under the title, so the card reads as a titled panel
             * rather than a loose list of words — and it is drawn in the accent,
             * fading out at both ends, which is the card's one mark of ink above
             * the list. */
            Item {
                visible: header.visible
                width: parent.width
                height: titleGlyph.height + 6 * root.s

                GlyphIcon {
                    id: titleGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * root.s
                    height: width
                    name: "ukishima"
                    color: Theme.vermLit
                    stroke: 1.8
                }

                Rectangle {
                    anchors.left: titleGlyph.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8 * root.s
                    height: 2 * root.s
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.alpha(Theme.vermLit, 0.7) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            /** A short list: a row of tiles, the applied one ticked. The fill
             * lives in `tileCursor` behind them and morphs from tile to tile; a
             * tile never fills itself, so two options can never both look
             * chosen. */
            Item {
                id: tileStage

                visible: root.tiles
                width: parent.width
                height: tileRow.height

                Rectangle {
                    id: tileCursor

                    readonly property var target: (Selector.index >= 0 && Selector.index < tileRep.count)
                                                  ? tileRep.itemAt(Selector.index) : null

                    visible: tileCursor.target !== null
                    x: tileCursor.target ? tileCursor.target.x : 0
                    y: tileCursor.target ? tileCursor.target.y : 0
                    width: tileCursor.target ? tileCursor.target.width : 0
                    height: tileCursor.target ? tileCursor.target.height : 0
                    radius: 13 * root.s
                    color: "transparent"

                    /** Lit from the top like the card it sits in, so the fill has
                     * body instead of being a flat wash. */
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.alpha(Theme.vermLit, 0.20) }
                        GradientStop { position: 1.0; color: Qt.alpha(Theme.vermLit, 0.09) }
                    }

                    Behavior on x {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                    Behavior on width {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                }

                Row {
                    id: tileRow

                    width: parent.width
                    spacing: root.tileGap

                    Repeater {
                        id: tileRep

                        model: root.tiles ? Selector.options : []

                        Rectangle {
                            id: tile

                            required property var modelData
                            required property int index

                            readonly property bool current: String(Selector.value) === String(tile.modelData.value)
                            readonly property bool lit: Selector.index === tile.index
                            readonly property bool hasIcon: tile.modelData.icon !== undefined && String(tile.modelData.icon).length > 0
                            readonly property color ink: tile.current ? Theme.vermLit
                                                       : (tile.lit ? Theme.cream : Theme.subtle)

                            width: (tileRow.width - root.tileGap * (root.tileCols - 1)) / root.tileCols
                            height: card.tileH
                            radius: 13 * root.s
                            color: "transparent"
                            border.width: 0

                            /** The glyph on a raised plate over the name — the
                             * plate is what makes a tile read as a button and
                             * not as an outlined box. An option with no glyph of
                             * its own is just its name, set large and centred:
                             * a bare "100%" then fills a panel instead of
                             * floating in an empty one. */
                            Item {
                                id: tileBody

                                anchors.centerIn: parent
                                width: tile.width - 18 * root.s
                                height: (tile.hasIcon ? 46 * root.s + 11 * root.s : 0) + tileLabel.implicitHeight

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: tile.hasIcon
                                    width: 46 * root.s
                                    height: width
                                    radius: 14 * root.s
                                    color: tile.lit ? Qt.alpha(Theme.cream, 0.10) : Theme.frameBg
                                    border.width: 1
                                    border.color: tile.lit ? Qt.alpha(Theme.vermLit, 0.30) : Theme.frameBorder

                                    GlyphIcon {
                                        anchors.centerIn: parent
                                        width: 26 * root.s
                                        height: width
                                        name: tile.hasIcon ? tile.modelData.icon : ""
                                        color: tile.ink
                                        stroke: 1.6
                                    }
                                }

                                Text {
                                    id: tileLabel

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tile.modelData.label
                                    color: tile.ink
                                    font.family: Theme.font
                                    font.pixelSize: (tile.hasIcon ? 12.5 : 15) * root.s
                                    font.weight: tile.current ? Font.Bold : (tile.lit ? Font.DemiBold : Font.Medium)
                                }
                            }

                            /** The tick keeps saying *value* while the fill says
                             * *cursor*, which is the whole reason both can be
                             * seen at once. */
                            GlyphIcon {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 10 * root.s
                                visible: tile.current
                                width: 14 * root.s
                                height: 14 * root.s
                                name: "check"
                                color: Theme.vermLit
                                stroke: 2.2

                                /** The tick arrives with the card, a beat after
                                 * the tiles do. */
                                scale: root.active ? 1 : 0.55
                                Behavior on scale { NumberAnimation { duration: Motion.pillFast; easing.type: Easing.OutBack } }
                            }

                            MouseArea {
                                id: tileHit

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    Selector.index = tile.index;
                                    card.pointAt(tileHit);
                                }
                                onPositionChanged: card.pointAt(tileHit)
                                onClicked: Selector.pick(tile.modelData.value)
                            }

                            /** A tiny floor shine along the top of the plate: does
                             * nothing to selection logic, but sells the button
                             * surface. */
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: tile.width < 120 * root.s ? parent.left : tileBody.left
                                anchors.right: tile.width < 120 * root.s ? parent.right : tileBody.right
                                anchors.topMargin: 2 * root.s
                                height: 1
                                radius: 0.5
                                opacity: tile.lit ? 0.35 : 0.18
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.alpha(Theme.cream, 0.18) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }
                    }
                }

                /** An aim mark riding three pixels outside the fill, so the
                 * travelling highlight has an outline to land in. It reads the
                 * fill's own animated geometry, so it travels with it. */
                Rectangle {
                    visible: tileCursor.target !== null
                    x: tileCursor.x - 3 * root.s
                    y: tileCursor.y - 3 * root.s
                    width: tileCursor.width + 6 * root.s
                    height: tileCursor.height + 6 * root.s
                    radius: 16 * root.s
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.vermLit, 0.26)
                }
            }

            /** A long list: chips wrapping under the card's width cap. The same
             * travelling fill sits behind them and morphs from one chip to the
             * next, and the same marks tell cursor and value apart. */
            Item {
                id: chipStage

                visible: !root.tiles
                width: parent.width
                height: flow.height

                Rectangle {
                    id: chipCursor

                    readonly property var target: (Selector.index >= 0 && Selector.index < chipRep.count)
                                                  ? chipRep.itemAt(Selector.index) : null

                    visible: chipCursor.target !== null
                    x: chipCursor.target ? chipCursor.target.x : 0
                    y: chipCursor.target ? chipCursor.target.y : 0
                    width: chipCursor.target ? chipCursor.target.width : 0
                    height: chipCursor.target ? chipCursor.target.height : 0
                    radius: height / 2
                    color: Qt.alpha(Theme.vermLit, 0.16)

                    Behavior on x {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                    Behavior on y {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                    Behavior on width {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                    Behavior on height {
                        enabled: card.ready
                        NumberAnimation {
                            duration: Motion.pillFast
                            easing.type: Motion.pillEase
                        }
                    }
                }

                Flow {
                    id: flow

                    width: parent.width
                    spacing: 8 * root.s

                    Repeater {
                        id: chipRep

                        model: root.tiles ? [] : Selector.options
                        onItemAdded: root.optionRev++
                        onItemRemoved: root.optionRev++

                        Rectangle {
                            id: chip

                            required property var modelData
                            required property int index

                            readonly property bool current: String(Selector.value) === String(chip.modelData.value)
                            readonly property bool lit: Selector.index === chip.index
                            readonly property bool hasIcon: chip.modelData.icon !== undefined && String(chip.modelData.icon).length > 0
                            readonly property color ink: chip.current ? Theme.vermLit : (chip.lit ? Theme.cream : Theme.subtle)
                            readonly property real naturalW: chipRow.implicitWidth + 26 * root.s

                            onNaturalWChanged: root.optionRev++
                            width: chip.naturalW
                            height: 32 * root.s
                            radius: height / 2
                            color: "transparent"
                            border.width: 0

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 7 * root.s

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: chip.current
                                    width: 14 * root.s
                                    height: 14 * root.s
                                    name: "check"
                                    color: Theme.vermLit
                                    stroke: 2.2
                                    scale: root.active ? 1 : 0.55
                                    Behavior on scale { NumberAnimation { duration: Motion.pillFast; easing.type: Easing.OutBack } }
                                }

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: chip.hasIcon
                                    width: 16 * root.s
                                    height: 16 * root.s
                                    name: chip.hasIcon ? chip.modelData.icon : ""
                                    color: chip.ink
                                    stroke: 1.7
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    color: chip.ink
                                    font.family: Theme.font
                                    font.pixelSize: 12.5 * root.s
                                    font.weight: chip.current ? Font.Bold : (chip.lit ? Font.DemiBold : Font.Medium)
                                }
                            }

                            MouseArea {
                                id: chipHit

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    Selector.index = chip.index;
                                    card.pointAt(chipHit);
                                }
                                onPositionChanged: card.pointAt(chipHit)
                                onClicked: Selector.pick(chip.modelData.value)
                            }
                        }
                    }
                }
            }

            /** The keys, said where a short list leaves room. This card is the
             * one surface in the shell driven entirely from the keyboard, so it
             * says how — and each hint wears the key cap it names. */
            Item {
                width: parent.width
                height: hintRow.implicitHeight

                Row {
                    id: hintRow

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6 * root.s

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26 * root.s
                        height: 19 * root.s
                        radius: 6 * root.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder

                        Text {
                            anchors.centerIn: parent
                            text: "←→"
                            color: Theme.creamMenu
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "move"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.1 * root.s
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: Theme.faint
                        font.pixelSize: 11 * root.s
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24 * root.s
                        height: 19 * root.s
                        radius: 6 * root.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder

                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 12 * root.s
                            height: width
                            name: "return"
                            color: Theme.creamMenu
                            stroke: 1.7
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "pick"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.1 * root.s
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28 * root.s
                        height: 19 * root.s
                        radius: 6 * root.s
                        color: Theme.frameBg
                        border.width: 1
                        border.color: Theme.frameBorder

                        Text {
                            anchors.centerIn: parent
                            text: "esc"
                            color: Theme.creamMenu
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.6 * root.s
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "close"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.1 * root.s
                    }
                }
            }
        }
    }

    /** One 600ms pass of the light, restarted on each open. */
    NumberAnimation {
        id: sweepRun

        target: sweep
        property: "progress"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }

    Timer {
        id: readyTimer
        interval: 160
        onTriggered: card.ready = true
    }
}
