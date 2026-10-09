pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../Singletons"
import "../components"

/**
 * Scratchpad surface: a shelf of plain-text notes drawn as one of the pill's
 * surfaces. One file per note, the title is the filename, pinned notes sort to
 * the top. The pad has two pages rather than a permanent list beside an editor.
 *
 * The DECK is the whole surface: every note as a card, showing its first lines,
 * with New as the first card and nothing else competing for the width. Opening a
 * card fills the surface with that note — the NOTE page — a title field, a
 * divider and the body. Escape goes back to the deck, and from the deck out.
 *
 * A rail was the first cut of this and it was the wrong shape: at 526px wide a
 * 150px rail leaves the editor barely more room than the deck's cards, while
 * costing a permanent column on the one page that did not need one. Going
 * full-surface per page buys the body about 60px of width and 80px of height,
 * which is the difference between a note you can read and one you can only
 * skim.
 *
 * New does not write a file straight away. The note page opens in NAMING state
 * with only the title field live, and nothing reaches the disk until Enter gives
 * the note a name — a note has no identity without one, since the name is the
 * filename. A name that sanitizes to nothing keeps the field open rather than
 * leaving a stray untitled file behind. A note created this way and left blank
 * is discarded on the way out, so abandoning "New" leaves nothing to clean up.
 *
 * The title is a rename target, not a label: Enter commits and refuses to clobber
 * an existing note, Escape reverts. Tab and Down move from title into the body,
 * Shift+Tab and Up on the first line come back, so the whole note is reachable
 * without the mouse. The body is a TextArea bound one-way into the model, flushed
 * on a short debounce so a fast close cannot eat the last keystrokes. Delete is a
 * heat-hold, matching the clipboard wipe; clearing the body is a plain click,
 * since typing undoes it.
 *
 * Bodies are shown as written. Lines beginning `[ ]` are left as they are rather
 * than drawn as checkboxes: that needs private-use icon codepoints, and the mono
 * face this resolves to is a plain Iosevka, so the glyphs would land as tofu.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 15
    mRight: 15
    mBottom: 14

    /** "deck" is the card grid, "note" is one note full-surface. */
    property string page: "deck"

    /**
     * The note page is naming a note rather than editing one: no file exists and
     * only the title field takes input. Enter leaves this state, Escape abandons.
     */
    property bool naming: false

    /** Editor debounce: long enough to coalesce a burst of typing, short enough to feel saved. */
    readonly property int saveMs: 500

    /**
     * A glyph or ring that is carrying state, rather than resting.
     *
     * The obvious token is the accent, and it is the wrong one here: the default
     * accent is a light warm orange that scores 1.64:1 against the light-mode
     * surface and 8.82:1 against the dark one, so a pin or a focus ring drawn in
     * it is nearly invisible in light mode and fine in dark — the opposite of
     * "works in every mode". `subtle` clears 3:1 in both (5.56:1 light, 7.75:1
     * dark), so the lit states use it and the accent stays on the pin mark and
     * the delete heat, which are drawn on a tile rather than the bare surface and
     * are the one place the hue carries meaning.
     */
    readonly property color lit: Theme.subtle

    readonly property bool hasNote: Scratch.current !== null
    readonly property bool onNote: root.page === "note"

    /**
     * The flame sits under the body caret while a note is open — the same
     * `caret` form the search surfaces use — and is off on the deck and while
     * naming, where nothing is being typed.
     */
    readonly property point caretPoint: {
        void root.width;
        void root.height;
        void bodyInput.width;
        return bodyInput.mapToItem(root,
            bodyInput.cursorRectangle.x + bodyInput.cursorRectangle.width / 2,
            bodyInput.cursorRectangle.y + bodyInput.cursorRectangle.height / 2);
    }
    ameForm: root.onNote && root.hasNote && !root.naming ? "caret" : "off"
    amePoint: caretPoint

    /**
     * Whether the sheet draws at all. Naming is included deliberately: while naming
     * there is no note behind the page yet, but the title field *is* the page, so
     * gating the header on `hasNote` would hide the one thing being asked for.
     */
    readonly property bool sheetVisible: root.hasNote || root.naming

    /**
     * The note this surface created that has never been written on, so leaving it
     * blank can discard exactly that note. Scoped to one visit on purpose: a note
     * that already had content and was then deliberately emptied is kept, not
     * deleted out from under a user who only asked to clear it.
     */
    property string bornSlug: ""

    /** Title field text, seeded from the model and only rewritten on selection change. */
    property string titleDraft: ""

    /**
     * The editor buffer is the model's `draft` directly, one-way in: every edit
     * writes straight through to the singleton and arms the debounce, so the
     * editor never holds a second copy that can drift from the model (the failure
     * mode where a reopen shows stale text).
     */
    readonly property string body: Scratch.draft
    onBodyChanged: if (root.hasNote) saveTimer.restart()

    Timer {
        id: saveTimer
        interval: root.saveMs
        onTriggered: Scratch.save()
    }

    /**
     * Flush before the surface goes away, so a dismiss inside the debounce
     * window cannot eat the last keystrokes. The blank-discard happens on the way
     * out too, which is why closing goes through `leave()` rather than just
     * saving.
     */
    function flush() {
        saveTimer.stop();
        Scratch.save();
    }

    onActiveChanged: {
        Scratch.surfaceOpen = root.active;
        if (!root.active) {
            root.leave();
            return;
        }
        Scratch.scan();
        //* Always reopens on the deck, so the pad comes back the way it was
        //* summoned: a shelf of notes, not the last one left open.
        root.showDeck();
    }

    /** The deck, with the keyboard ring on the note that was open. */
    function showDeck() {
        root.commitTitle();
        root.leave();
        root.page = "deck";
        deckGrid.forceActiveFocus();
    }

    /**
     * Discard a note this visit created and never wrote on, then drop the
     * selection if that note was it. Called on every exit — Escape to the deck and
     * the pill dismissing the surface — so neither route can leave an empty note
     * behind. A note being written on is untouched, and so is any note that was
     * here before this visit.
     */
    function leave() {
        root.flush();
        if (!root.bornSlug)
            return;
        var stale = root.bornSlug;
        root.bornSlug = "";
        if (Scratch.currentSlug !== stale || !Scratch.isEmpty(stale))
            return;
        //* Only ever the note we are sitting on: a note the user has since navigated
        //* away from, or filled in, belongs to them.
        Scratch.remove(stale);
    }

    /**
     * Connections live here rather than in the page bodies. QML drops signal
     * connections made inside a type whose instantiation was itself triggered from
     * a signal handler — which is exactly how this surface opens — so a handler
     * attached to the editor would silently never fire.
     */
    Connections {
        target: Scratch
        function onCurrentSlugChanged() { root.seedTitle(); }
        function onNotesChanged() {
            //* Bare id, not `root.deckGrid`: `deckGrid` lives inside the deck
            //* FocusScope, and under `pragma ComponentBehavior: Bound` it is not
            //* reachable as a property of the root.
            deckGrid.locateCurrent();
        }
    }

    // ---------------------------------------------------------------- deck ---

    FocusScope {
        id: deck
        anchors.fill: parent
        focus: root.page === "deck"
        visible: root.page === "deck"
        enabled: root.page === "deck"

        Keys.onEscapePressed: root.requestClose()

        readonly property real gap: 10 * root.s

        /**
         * Columns are chosen from a target card width rather than hardcoded, so the
         * grid keeps its shape as the pill is scaled: `s` shrinks the target and
         * the cards with it instead of dropping to two wide on a small screen.
         */
        readonly property int cols: Math.max(1, Math.floor((deck.width + deck.gap) / (160 * root.s + deck.gap)))

        /**
         * GridView has no `columns` property: it derives its own from
         * `floor(width / cellWidth)`, and the arrow keys walk by that. Dividing the
         * width by the intended count makes the two agree exactly — a card width
         * that merely happened to look right would leave Up and Down hopping by a
         * different column count than the grid was drawn with.
         */
        readonly property real pitch: deck.width / deck.cols
        readonly property real cardW: deck.pitch - deck.gap
        //* Measured against the grid, not the deck: the header band above it would
        //* otherwise be counted as card room and push the second row off the foot.
        readonly property real cardH: Math.max(0, Math.min(104 * root.s, (deckGrid.height - deck.gap) / 2))

        /**
         * New is the first card, so the deck is one list you walk with the arrows
         * rather than a grid plus a separate button the keyboard cannot reach.
         */
        readonly property var cards: [{ fresh: true }].concat(Scratch.notes)

        Component.onCompleted: deckGrid.forceActiveFocus()

        /**
         * Read-only counterpart to the sibling surfaces' search band: the 記 glyph,
         * the pad's name and the shelf's count over the same hairline divider that
         * Clipboard and Wallpaper draw. It carries no input, so the deck stays a
         * grid you walk with the arrows rather than a search-first list.
         *
         * Height and divider offset match the note page's header exactly, so the
         * band does not jump when a card opens or Escape comes back.
         */
        Item {
            id: deckHead
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26 * root.s

            Text {
                id: deckGlyph
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                visible: Flags.showGlyphs
                width: Flags.showGlyphs ? implicitWidth : 0
                text: "記"
                color: Theme.dim
                font.family: Theme.fontJp
                font.weight: Theme.fontJpWeight
                font.pixelSize: 13 * root.s
            }

            Text {
                anchors.left: deckGlyph.right
                anchors.leftMargin: Flags.showGlyphs ? 9 * root.s : 0
                anchors.verticalCenter: parent.verticalCenter
                text: "Scratchpad"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: foot.summary
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.features: { "tnum": 1 }
            }
        }

        Rectangle {
            id: deckDivider
            anchors.top: deckHead.bottom
            anchors.topMargin: 7 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        GridView {
            id: deckGrid
            objectName: "deckGrid"

            anchors.top: deckDivider.bottom
            anchors.topMargin: 10 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            //* The deck stops well clear of the footer: a floating last row reads
            //* better than tiles running down into the hints bar.
            anchors.bottomMargin: foot.height + 30 * root.s
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: deck.pitch
            cellHeight: deck.cardH + deck.gap
            model: deck.cards
            focus: true
            currentIndex: 0

            /**
             * Put the ring back on the open note after a rescan.
             *
             * This runs on the note page too, and has to: every autosave rescans,
             * which replaces `deck.cards` with a fresh array, and a GridView resets
             * `currentIndex` to 0 whenever its model is reassigned. Gating this on
             * `page === "deck"` would mean the ring was already lost by the time the
             * user came back — Escape would land them on New instead of the note
             * they just left.
             *
             * With nothing open there is no note to return to, so the ring stays
             * where the user walked it.
             */
            function locateCurrent() {
                if (!Scratch.currentSlug)
                    return;
                for (var i = 0; i < deck.cards.length; i++) {
                    var c = deck.cards[i];
                    if (!c.fresh && c.slug === Scratch.currentSlug) {
                        currentIndex = i;
                        return;
                    }
                }
            }

            /** The note the ring is on, or null on New. */
            readonly property var ringed: {
                var c = deck.cards[currentIndex];
                return c && c.fresh !== true ? c : null;
            }

            Keys.onLeftPressed: moveCurrentIndexLeft()
            Keys.onRightPressed: moveCurrentIndexRight()
            Keys.onDownPressed: moveCurrentIndexDown()
            Keys.onUpPressed: moveCurrentIndexUp()
            Keys.onReturnPressed: deck.openRinged()
            Keys.onEnterPressed: deck.openRinged()
            Keys.onSpacePressed: deck.openRinged()
            Keys.onDeletePressed: deck.deleteRinged()

            delegate: Item {
                id: slot

                required property int index
                required property var modelData

                readonly property var card: slot.modelData
                readonly property bool fresh: slot.card.fresh === true
                readonly property bool ringed: deckGrid.activeFocus && deckGrid.currentIndex === slot.index
                readonly property bool hovering: slotHover.hovered

                width: deck.cardW
                height: deck.cardH

                HoverHandler { id: slotHover }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    //* Press, not click: the ring should follow the pointer, so the
                    //* card you are about to open is already the one Escape returns to.
                    onPressed: deckGrid.currentIndex = slot.index
                    onClicked: deck.openRinged()
                }

                //* New: dashed ground and a plus, so it reads as an action rather
                //* than a note that happens to have no text.
                Rectangle {
                    anchors.fill: parent
                    visible: slot.fresh
                    radius: 9 * root.s
                    color: tap.containsMouse ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: slot.ringed ? root.lit : (tap.containsMouse ? Theme.frameBorder : Theme.hairSoft)

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 5 * root.s

                        GlyphIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 13 * root.s
                            height: 13 * root.s
                            name: "plus"
                            stroke: 1.8
                            color: slot.ringed || tap.containsMouse ? root.lit : Theme.faint
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "New note"
                            color: slot.ringed ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                        }
                    }
                }

                //* A note: its own first lines, so the deck is worth scanning.
                Rectangle {
                    id: tile
                    anchors.fill: parent
                    visible: !slot.fresh
                    radius: 9 * root.s
                    //* Resting cards carry the same faint warm veil a hovered row
                    //* uses elsewhere; hover and ring lift to the frame fill and
                    //* border that mark the selected row in the Clipboard list, so a
                    //* ringed card reads as "this one" across the surfaces.
                    color: slot.hovering || slot.ringed ? Theme.frameBg : Qt.rgba(0.94, 0.88, 0.84, 0.035)
                    border.width: 1
                    border.color: slot.ringed ? root.lit : Theme.hairSoft

                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    //* The text column starts after the pin when one is drawn, so a
                    //* pinned card's title, heading and preview share one edge instead
                    //* of the body jutting out under the mark.
                    readonly property real contentLeft: pinMark.visible ? pinMark.right + 5 * root.s : 9 * root.s

                    GlyphIcon {
                        id: pinMark
                        anchors.top: parent.top
                        anchors.topMargin: 8 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        width: 8 * root.s
                        height: 8 * root.s
                        name: "pin"
                        stroke: 1.8
                        visible: slot.card.pinned === true
                        //* This mark is what separates a pinned card from the rest.
                        //* `lit` rather than the accent: the surface's design notes
                        //* document the accent as nearly invisible on the light
                        //* surface (1.64:1), which made the pin look missing there —
                        //* exactly the "pin did nothing" report this fixes. A pin
                        //* state marker follows the same lit token the header glyph
                        //* uses, which clears 3:1 in both modes.
                        color: root.lit
                    }

                    Text {
                        id: cardTitle
                        anchors.top: parent.top
                        anchors.topMargin: 7 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: tile.contentLeft
                        anchors.right: ageTag.left
                        anchors.rightMargin: 5 * root.s
                        text: slot.card.title ?? ""
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }

                    Text {
                        id: ageTag
                        anchors.top: parent.top
                        anchors.topMargin: 8 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 9 * root.s
                        text: slot.card.age ?? ""
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.features: { "tnum": 1 }
                    }

                    //* The note's own lead line, kept distinct from the filename: set by the
                    //* model from a body that opens with a heading. Carried in the title
                    //* face and the same cream so it reads as the note's real name, but
                    //* smaller and lighter than the DemiBold filename; the mono preview
                    //* below sits in the dimmer `subtle` so heading and body read as two
                    //* clearly separated colors.
                    Text {
                        id: cardHeading
                        anchors.top: cardTitle.bottom
                        anchors.topMargin: 5 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: tile.contentLeft
                        anchors.right: parent.right
                        anchors.rightMargin: 9 * root.s
                        visible: slot.card.heading !== undefined && slot.card.heading !== ""
                        text: slot.card.heading ?? ""
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }

                    Text {
                        id: cardBody
                        anchors.top: cardHeading.visible ? cardHeading.bottom : cardTitle.bottom
                        anchors.topMargin: 7 * root.s
                        anchors.left: parent.left
                        anchors.leftMargin: tile.contentLeft
                        anchors.right: parent.right
                        anchors.rightMargin: 9 * root.s
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8 * root.s
                        text: slot.card.preview !== undefined && slot.card.preview !== ""
                            ? slot.card.preview
                            : "empty"
                        color: slot.card.preview ? Theme.subtle : Theme.faint
                        font.family: Theme.fontMono
                        font.pixelSize: 11 * root.s
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: cardHeading.visible ? 3 : 4
                        lineHeight: 1.3
                    }
                }
            }
        }

        WheelScroller {
            anchors.fill: deckGrid
            s: root.s
            flick: deckGrid
        }

        //* Just the key hints now: the shelf's count moved up into the header band,
        //* where the sibling surfaces keep it.
        Item {
            id: foot
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 14 * root.s

            readonly property int n: Scratch.notes.length
            readonly property int pinned: {
                var c = 0;
                for (var i = 0; i < Scratch.notes.length; i++)
                    if (Scratch.notes[i].pinned === true)
                        c++;
                return c;
            }

            //* Shared with the header band, so the count lives in one place.
            readonly property string summary: n === 0 ? "nothing written down yet"
                : n + (n === 1 ? " note" : " notes") + (pinned > 0 ? " · " + pinned + " pinned" : "")

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: "enter opens · del removes · esc closes"
                color: Qt.alpha(Theme.faint, 0.7)
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
            }
        }

        /** Open the ringed card, or start a new note from the New card. */
        function openRinged() {
            var note = deckGrid.ringed;
            if (!note) {
                root.openCreate();
                return;
            }
            Scratch.select(note.slug);
            root.page = "note";
            deckGrid.locateCurrent();
            //* Without this the body is drawn but never focused, so the first
            //* keystroke after opening a card went nowhere until the user clicked.
            root.focusBody();
        }

        function deleteRinged() {
            var note = deckGrid.ringed;
            if (note)
                Scratch.remove(note.slug);
        }
    }

    // ---------------------------------------------------------------- note ---

    FocusScope {
        id: note
        anchors.fill: parent
        focus: root.onNote
        visible: root.onNote
        enabled: root.onNote

        Keys.onEscapePressed: root.leaveNote()

        Text {
            id: noNote
            anchors.centerIn: parent
            visible: !root.sheetVisible
            text: "That note is gone"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11 * root.s
        }

        Item {
            id: head
            //* The header's tooltips hang below their buttons and are `z: 20`, but
            //* z only orders within one parent's subtree — and the body's ScrollView
            //* is a later sibling of this, so without a lift here it paints straight
            //* over the bubbles and the note name box swallows them.
            z: 10
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26 * root.s
            visible: root.sheetVisible

            Item {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                visible: !root.naming

                Tooltip {
                    s: root.s
                    placement: "below"
                    title: "back to notes"
                    show: backArea.containsMouse
                }

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    stroke: 2
                    color: backArea.containsMouse ? Theme.cream : Theme.faint
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showDeck()
                }
            }

            TextEdit {
                id: titleInput
                anchors.left: backBtn.visible ? backBtn.right : parent.left
                anchors.leftMargin: backBtn.visible ? 7 * root.s : 0
                anchors.right: actions.left
                anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 24 * root.s
                padding: 3 * root.s
                readOnly: !root.sheetVisible
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13.5 * root.s
                font.weight: Font.DemiBold
                //* Selection is a filled block with ink on it, so the pair that
                //* matters is the text against the fill — not the fill against the
                //* surface. No single theme token clears 4.5:1 for ink in both modes,
                //* and accent is the worst of them here (1.77:1 on the ink in dark).
                //* `verm` is what Wallpaper, Wifi, LockSettings and AccentSurface all
                //* use for the same job, at 4.33:1 dark and 2.99:1 light.
                selectionColor: Theme.verm
                selectedTextColor: Theme.cream
                clip: true

                //* Two-way with `titleDraft`, which is what commitTitle reads. Without
                //* this the field would hold a name the model never sees, and every
                //* rename would silently commit the previous note's title.
                text: root.titleDraft
                onTextEdited: root.titleDraft = text

                /**
                 * Naming: Enter is the only way out, and it creates rather than
                 * renames. Escape abandons and never reaches the surface, since the
                 * user asked to back out of a half-made note, not to leave the pad.
                 */
                function accept() {
                    if (root.naming)
                        root.confirmName();
                    else {
                        root.commitTitle();
                        root.focusBody();
                    }
                }

                /**
                 * Tab and Down reach the body, so the whole note is reachable without
                 * the mouse. Left unaccepted while naming so Tab still moves focus
                 * normally instead of being swallowed into a body that does not exist.
                 */
                function intoBody() {
                    if (!root.naming)
                        root.focusBody();
                }

                Keys.onReturnPressed: accept()
                Keys.onEnterPressed: accept()
                Keys.onTabPressed: intoBody()
                Keys.onBacktabPressed: intoBody()
                Keys.onDownPressed: intoBody()

                //* The title is the filename, so blur commits the rename. Skipped
                //* while naming: there is no file to rename yet.
                onActiveFocusChanged: {
                    if (!activeFocus && !root.naming)
                        root.commitTitle();
                }

                //* A blank title field is a prompt, not a gap.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 3 * root.s
                    visible: titleInput.text === ""
                    text: root.naming ? "name this note…" : "Untitled"
                    font: titleInput.font
                    color: Theme.faint
                }
            }

            //* Sizing-only container for the three header buttons — it exists so
            //* the title field can reserve room, and must not paint. A `Rectangle`
            //* defaults to opaque white, which was laying a white panel under the
            //* pin, clear and delete glyphs and drowning all three of them; an
            //* `Item` cannot paint at all.
            Item {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: row3.width + clearBtn.width + delBtn.width + 16 * root.s
                height: 22 * root.s
                visible: !root.naming

                Item {
                    id: row3
                    anchors.right: clearBtn.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: pinHead.width
                    height: 22 * root.s

                    //* Unsaved marker: the dot only exists while a write is pending, so a
                    //* clean pad has no dot at rest and "saved" needs no label.
                    Rectangle {
                        id: saveDot
                        anchors.right: pinHead.left
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5 * root.s
                        height: 5 * root.s
                        radius: width / 2
                        visible: Scratch.dirty || saveTimer.running
                        //* A 5px dot has no stroke to carry it, so it is held to the
                        //* 3:1 a graphical mark needs; accent alone is 1.64:1 on the
                        //* light surface. The bar it sits on is what fills red as the
                        //* delete hold charges.
                        color: root.lit
                    }

                    Item {
                        id: pinHead
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s

                        Tooltip {
                            s: root.s
                            placement: "below"
                            title: Scratch.current && Scratch.current.pinned ? "unpin" : "pin"
                            show: pinHeadArea.containsMouse
                        }

                        GlyphIcon {
                            anchors.fill: parent
                            name: "pin"
                            stroke: 1.8
                            color: Scratch.current && Scratch.current.pinned ? root.lit
                                : (pinHeadArea.containsMouse ? Theme.cream : Theme.faint)
                        }

                        MouseArea {
                            id: pinHeadArea
                            anchors.fill: parent
                            anchors.margins: -4 * root.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Scratch.togglePin(Scratch.currentSlug)
                        }
                    }
                }

                Item {
                    id: clearBtn
                    anchors.right: delBtn.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * root.s
                    height: 16 * root.s
                    visible: root.body !== ""

                    Tooltip {
                        s: root.s
                        placement: "below"
                        title: "clear body"
                        show: clearArea.containsMouse
                    }

                    GlyphIcon {
                        anchors.fill: parent
                        name: "close"
                        stroke: 1.7
                        color: clearArea.containsMouse ? Theme.cream : Theme.faint
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Scratch.clearBody()
                    }
                }

                Item {
                    id: delBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * root.s
                    height: 16 * root.s

                    readonly property real hold: delHeat.hold
                    readonly property bool holding: delHeat.holding
                    //* Resting at `faint`, not `cream` or `iconDim`: a full-brightness
                    //* glyph here reads as three loud buttons parked next to a note
                    //* title, which is not what the header is for. The heat ramps
                    //* verm → vermLit so the destructive intent shows up on the press
                    //* rather than sitting there waiting.
                    readonly property color tone: holding ? Theme.vermLit
                        : (delArea.containsMouse ? Theme.verm : Theme.faint)

                    Tooltip {
                        s: root.s
                        placement: "below"
                        title: delBtn.holding ? "keep holding" : "hold to delete"
                        show: delArea.containsMouse || delBtn.holding
                    }

                    GlyphIcon {
                        anchors.fill: parent
                        name: "trash"
                        stroke: 1.7
                        color: delBtn.tone
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    HeatHold {
                        id: delHeat
                        //* HeatHold only fires `confirmed`; without this the fill
                        //* would run to full and nothing would happen. Deleting from
                        //* the note page hands back to the deck, because the note
                        //* that was open is the one that just went away.
                        onConfirmed: root.deleteCurrent()
                    }

                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: delHeat.press()
                        onReleased: delHeat.release()
                        onExited: delHeat.cancel()
                    }
                }
            }
        }

        //* A sibling of the header and the editor, not a child of either: the
        //* editor anchors to this, and QML only allows anchoring to a parent or
        //* a sibling. The heat-fill drains along it, same as the clipboard wipe.
        Rectangle {
            id: headDivider
            anchors.top: head.bottom
            anchors.topMargin: 7 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
            visible: root.sheetVisible

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: parent.width * delBtn.hold
                visible: delBtn.holding
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.vermLit, 0.15) }
                    GradientStop { position: 1.0; color: Theme.vermLit }
                }
            }
        }

        /**
         * While naming there is no body to edit, so the field gets the whole space
         * and the editor is hidden. `hasNote` is false here by construction — no
         * file has been written — so this is also the only state in which the note
         * page is showing without a note behind it.
         */
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: headDivider.bottom
            anchors.topMargin: 10 * root.s
            horizontalAlignment: Text.AlignHCenter
            visible: root.naming
            text: "the note's name is its filename"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
        }

        //* Wrapped in a ScrollView because a bare TextArea's own `flickable` is
        //* undefined on this Qt build — the scroll container's contentItem is the
        //* real Flickable, and that is what WheelScroller drives.
        ScrollView {
            id: bodyScroll
            anchors.top: headDivider.bottom
            anchors.topMargin: 8 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: statBar.top
            anchors.bottomMargin: 6 * root.s
            visible: root.hasNote && !root.naming
            clip: true
            //* No native scrollbar: it is the one control chrome in the pill that
            //* does not follow the theme, and WheelScroller drives the flick.
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            TextArea {
                id: bodyInput
                objectName: "bodyInput"

                //* No select-all-on-focus: a click into the body must place a caret,
                //* not wipe the note the moment the pad opens.
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: Theme.cream
                font.family: Theme.fontMono
                font.pixelSize: 13 * root.s
                //* Same reasoning as the title field's selection.
                selectionColor: Theme.verm
                selectedTextColor: Theme.cream
                background: null

                //* Focus is taken synchronously from `onActiveFocusChanged`, not from
                //* `onTextEdited`: the model's read for a note lands asynchronously, so
                //* a caret placed at read time would sit at the end of the old text,
                //* and clicking anywhere in the body would clear the note.
                onActiveFocusChanged: {
                    if (activeFocus && root.onNote)
                        cursorPosition = 0;
                }

                //* One-way into the model: the TextArea owns the caret and undo stack,
                //* the singleton owns the bytes. `text` is deliberately not bound —
                //* a binding would re-set `text` on every rescan and collapse undo.
                //
                //* The `!== draft` guard is what keeps opening a note from marking it
                //* dirty: loading a body assigns `text`, which fires this, which would
                //* arm a save of bytes identical to what is already on disk — a
                //* pointless write and rescan, and a "unsaved" dot on every open.
                onTextChanged: if (root.hasNote && text !== Scratch.draft) Scratch.type(text)

                //* The model's read/clear path lands here. Text is only ever assigned
                //* from this handler and from the user, so undo survives a rescan.
                Connections {
                    target: Scratch
                    function onBodyLoaded(slug, body) {
                        if (slug === Scratch.currentSlug)
                            bodyInput.text = body;
                    }
                }

                Keys.onEscapePressed: root.leaveNote()
                Keys.onTabPressed: root.focusTitle()
                Keys.onBacktabPressed: root.focusTitle()

                //* Up on the first line goes back to the title. Not Backspace at the
                //* start: held to clear the note, it would walk on into the title.
                Keys.onUpPressed: function (event) {
                    if (bodyInput.cursorRectangle.y < bodyInput.cursorRectangle.height)
                        root.focusTitle();
                    else
                        event.accepted = false;
                }
            }
        }

        WheelScroller {
            anchors.fill: bodyScroll
            s: root.s
            flick: bodyScroll.contentItem
            visible: bodyScroll.visible
        }

        //* A blank body reads as broken rather than ready, so it gets the same kind
        //* of prompt the title field shows when it is empty. A sibling of the
        //* ScrollView, not a child: the ScrollView expects a single content item.
        Text {
            anchors.left: bodyScroll.left
            anchors.top: bodyScroll.top
            anchors.leftMargin: bodyInput.leftPadding
            anchors.topMargin: bodyInput.topPadding
            visible: root.hasNote && !root.naming && bodyInput.text === ""
            text: "start writing…"
            color: Theme.faint
            font: bodyInput.font
        }

        //* An Item, not a Row: a Row lays its children out itself and rejects the
        //* left/right anchoring the two ends of a stat line need.
        Item {
            id: statBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 12 * root.s
            visible: root.sheetVisible && !root.naming

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bodyInput.text.length + " chars"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: pathTag.left
                text: Scratch.current
                    ? Scratch.notesDir.replace(Scratch.home, "~") + "/" + Scratch.current.title
                    : ""
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                elide: Text.ElideLeft
                width: Math.min(implicitWidth, statBar.width * 0.6)
                horizontalAlignment: Text.AlignRight
            }

            Text {
                id: pathTag
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: Scratch.current ? Scratch.ext : ""
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
            }
        }
    }

    // -------------------------------------------------------------- wiring ---

    /**
     * Leave the note. With a note open this is Escape's first stop: back to the
     * deck rather than out of the pad, so a mistyped Escape cannot throw away the
     * surface the user was reading.
     */
    function leaveNote() {
        if (root.naming) {
            root.abandonName();
            return;
        }
        root.commitTitle();
        root.leave();
        root.page = "deck";
        deckGrid.forceActiveFocus();
    }

    /**
     * Delete the open note and fall back to the deck.
     *
     * The model deliberately leaves nothing selected on a remove, so the choice of
     * where to land belongs here. A delete is a statement about the note, not about
     * the surface, so it hands back one page rather than closing the pad — and it
     * skips `leave()`, which would otherwise be asked to discard a slug that is
     * already gone.
     */
    function deleteCurrent() {
        var slug = Scratch.currentSlug;
        if (!slug)
            return;
        //* The slug is cleared before the page flips so the ring is not asked to
        //* follow a note that no longer exists.
        Scratch.remove(slug);
        if (root.bornSlug === slug)
            root.bornSlug = "";
        root.titleDraft = "";
        root.page = "deck";
        deckGrid.forceActiveFocus();
    }

    function commitTitle() {
        var slug = Scratch.currentSlug;
        if (!slug || root.naming || root.titleDraft === slug)
            return;
        //* rename() refuses an empty or colliding name. Either way the field snaps
        //* back to the real name, so it can never display a title that has no file.
        Scratch.rename(slug, root.titleDraft);
        root.revertTitle();
    }

    function revertTitle() {
        root.titleDraft = Scratch.currentSlug;
    }

    /**
     * Repopulate the title field from the model. Called on selection change and
     * after a commit, because the singleton is the only thing that knows the
     * post-rename slug (the `mv` is async, so `currentSlug` settles a tick later).
     */
    function seedTitle() {
        root.titleDraft = Scratch.currentSlug;
    }

    function focusBody() {
        if (root.naming || !root.hasNote)
            return;
        bodyInput.forceActiveFocus();
    }

    function focusTitle() {
        if (root.naming || !root.hasNote)
            return;
        titleInput.forceActiveFocus();
        titleInput.cursorPosition = titleInput.length;
    }

    /**
     * Start a new note. The note page opens in naming state with no file behind it
     * and the caret in the name field, because a name is the only thing a note
     * needs before it can exist.
     */
    function openCreate() {
        root.flush();
        root.bornSlug = "";
        Scratch.select("");
        root.page = "note";
        root.naming = true;
        root.titleDraft = "";
        titleInput.text = "";
        titleInput.forceActiveFocus();
    }

    /**
     * Name accepted. A name that sanitizes to nothing, or one already taken, keeps
     * the field open rather than failing silently — `create()` refuses both, and
     * staying put is the only way the user learns why nothing happened.
     */
    function confirmName() {
        var slug = Scratch.create(root.titleDraft);
        if (!slug)
            return;
        root.naming = false;
        root.bornSlug = slug;
        root.titleDraft = slug;
        //* Deliberately no `Scratch.scan()`. `create()` has already put the note in
        //* the list and selected it, and the file it shells out to may not exist yet;
        //* a scan landing in that window finds no such note, treats the selection as
        //* deleted and re-selects a different one — putting another note's body under
        //* the name just typed. The write path rescans once there are bytes to find.
        root.focusBody();
    }

    /** New abandoned: back to the deck, having written nothing. */
    function abandonName() {
        root.naming = false;
        root.titleDraft = "";
        root.page = "deck";
        deckGrid.forceActiveFocus();
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: if (root.active && !root.onNote) root.openCreate()
    }
}
