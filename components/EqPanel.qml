pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../Singletons"

/**
 * Equalizer body for the sound surface: the mode chips, the live spectrum and
 * ten band faders, the bass / treble / widen shelves, the AutoEQ headphone
 * picker and the night toggle. The sound surface swaps this in for its Apps and
 * Mic tabs; all the state lives in the `Sound` singleton, so the panel is pure
 * presentation.
 */
Item {
    id: root

    property real s: 1
    /** True while this panel is the mixer's visible view; gates the live cava process. */
    property bool live: false
    property int focusIndex: -1

    readonly property var labels: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property bool boostOpen: boostMenu.visible
    readonly property bool pickerOpen: aeqPanel.visible

    /** Ame anchor while a band is focused, in this panel's coords; the host maps it. */
    readonly property string ameForm: root.focusIndex >= 0 ? "tick" : "off"
    readonly property point amePoint: {
        void root.focusIndex;
        const b = bandRep.itemAt(root.focusIndex);
        return b ? b.tickCenter : Qt.point(width / 2, height / 2);
    }

    implicitHeight: col.implicitHeight
    opacity: Sound.eq ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Motion.standard } }

    onLiveChanged: if (!live) {
        root.focusIndex = -1;
        aeqPanel.close();
        boostMenu.close();
        root.aeqQuery = "";
    }

    /** Move band keyboard focus by `dir`, wrapping; a fresh focus lands on the first or last band. */
    function moveFocus(dir) {
        root.focusIndex = root.focusIndex < 0 ? (dir > 0 ? 0 : 9)
                                              : (root.focusIndex + dir + 10) % 10;
    }

    /** Nudge the focused band by `db` dB. No-op with no band focused. */
    function stepFocused(db) {
        if (root.focusIndex >= 0 && root.focusIndex < 10)
            Sound.setBand(root.focusIndex, Math.max(-Sound.range, Math.min(Sound.range, (Sound.current.bands[root.focusIndex] || 0) + db)));
    }

    function closePopovers() {
        aeqPanel.close();
        boostMenu.close();
    }

    function fmtDb(v) {
        return (v > 0 ? "+" : "") + (Math.round(v * 10) / 10);
    }

    /** Live spectrum behind the band tracks, drawn from cava's raw frames. */
    Process {
        id: spectrum
        running: root.live && Cava.available
        command: ["sh", "-c", "printf '%s' \"$1\" | cava -p /dev/stdin", "_",
            "[general]\nbars = 40\nframerate = 60\nautosens = 0\nsensitivity = 5500\n"
            + "[input]\nmethod = pipewire\nsource = auto\n"
            + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n"
            + "ascii_max_range = 1000\nbar_delimiter = 59\nframe_delimiter = 10\n"
            + "channels = mono\nmono_option = average\n[smoothing]\nnoise_reduction = 0.7\n"]
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < 40; i++)
                    out.push((parseInt(parts[i]) || 0) / 1000);
                root.levels = out;
            }
        }
        onRunningChanged: if (!running) root.levels = []
    }

    property var levels: []

    component TextButton: Text {
        id: tb
        signal clicked()
        color: tbArea.containsMouse ? Theme.cream : Theme.subtle
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        font.weight: Font.DemiBold
        MouseArea {
            id: tbArea
            anchors.fill: parent
            anchors.margins: -5 * root.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.clicked()
        }
    }

    component ModeChip: Rectangle {
        id: chip
        required property var modelData
        readonly property string name: modelData.name
        readonly property bool current: Sound.current.mode === name
        readonly property bool editingName: root.renaming === name

        width: (chip.editingName ? Math.max(nameInput.contentWidth, 36 * root.s) : chipLabel.implicitWidth) + 16 * root.s
        height: 22 * root.s
        radius: 8 * root.s
        color: chip.current ? Qt.alpha(Theme.onGlow, 0.16) : (chipHover.hovered ? Theme.frameBg : "transparent")
        border.width: 1
        border.color: chip.current ? Qt.alpha(Theme.onGlow, 0.4) : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        HoverHandler { id: chipHover }

        Text {
            id: chipLabel
            visible: !chip.editingName
            anchors.centerIn: parent
            text: chip.name + (chip.current && Sound.dirty ? " •" : "")
            color: chip.current ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Bold
            font.letterSpacing: 0.3 * root.s
        }

        TextInput {
            id: nameInput
            visible: chip.editingName
            anchors.centerIn: parent
            text: chip.name
            color: Theme.cream
            selectionColor: Theme.verm
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.Bold
            maximumLength: 18
            onVisibleChanged: if (visible) { forceActiveFocus(); selectAll(); }
            onAccepted: { Sound.rename(chip.name, text); root.renaming = ""; }
            onActiveFocusChanged: if (!activeFocus && chip.editingName) root.renaming = ""
            Keys.onEscapePressed: root.renaming = ""
        }

        MouseArea {
            anchors.fill: parent
            enabled: !chip.editingName
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!root.editing) Sound.pick(chip.name)
            onDoubleClicked: root.renaming = chip.name
        }

        Rectangle {
            visible: root.editing
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -4 * root.s
            anchors.topMargin: -4 * root.s
            width: 13 * root.s
            height: 13 * root.s
            radius: width / 2
            color: minusArea.containsMouse ? Theme.vermLit : Theme.verm

            Rectangle {
                anchors.centerIn: parent
                width: 6 * root.s
                height: 1.6 * root.s
                radius: height / 2
                color: Theme.bright
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sound.remove(chip.name)
            }
        }
    }

    component EqBand: Item {
        id: band
        required property int index
        readonly property real db: Sound.current.bands[index] || 0
        readonly property bool lit: root.focusIndex === index || bandDrag.pressed
        readonly property real trackH: 70 * root.s
        readonly property real tickY: (1 - (db + Sound.range) / (2 * Sound.range)) * trackH

        /** Tick centre in panel coords; y and width are voided so the mapping re-runs as the value or layout moves. */
        readonly property point tickCenter: {
            void band.tickY;
            void band.width;
            return track.mapToItem(root, track.width / 2, band.tickY);
        }

        width: bandsRow.width / 10
        height: 106 * root.s

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    root.focusIndex = band.index;
                else if (root.focusIndex === band.index)
                    root.focusIndex = -1;
            }
        }

        Text {
            id: dbLabel
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.fmtDb(band.db)
            color: band.lit ? Theme.cream : (band.db !== 0 ? Theme.subtle : Theme.faint)
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Item {
            id: track
            anchors.top: dbLabel.bottom
            anchors.topMargin: 4 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22 * root.s
            height: band.trackH

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * root.s
                height: parent.height
                radius: width / 2
                color: Theme.threadBg
            }

            Rectangle {
                anchors.centerIn: parent
                width: 9 * root.s
                height: 1
                color: Theme.hair
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * root.s
                radius: width / 2
                y: Math.min(band.tickY, band.trackH / 2)
                height: Math.abs(band.tickY - band.trackH / 2)
                color: band.lit ? Theme.vermLit : Theme.vermDim
                Behavior on y { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
                Behavior on height { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: band.tickY - height / 2
                width: 11 * root.s
                height: 2.5 * root.s
                radius: 2 * root.s
                color: Theme.tickRest
                opacity: band.lit ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                Behavior on y { enabled: !bandDrag.pressed; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
            }

            MouseArea {
                id: bandDrag
                anchors.fill: parent
                anchors.margins: -8 * root.s
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function setFromY(my) {
                    const t = Math.max(0, Math.min(1, (my - 8 * root.s) / band.trackH));
                    Sound.setBand(band.index, Math.round((1 - 2 * t) * Sound.range * 2) / 2);
                }
                onPressed: (e) => setFromY(e.y)
                onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
                onDoubleClicked: Sound.setBand(band.index, 0)
                onWheel: (w) => Sound.setBand(band.index, Math.max(-Sound.range, Math.min(Sound.range, band.db + (w.angleDelta.y > 0 ? 0.5 : -0.5))))
            }
        }

        Text {
            anchors.top: track.bottom
            anchors.topMargin: 5 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.labels[band.index]
            color: band.lit ? Theme.cream : Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.DemiBold
        }
    }

    component MiniShelf: Item {
        id: shelf
        property string label: ""
        property real value: 0
        property bool bipolar: true
        property string readout: ""
        signal moved(real v)

        readonly property bool lit: shelfHover.hovered || shelfDrag.pressed
        readonly property real clamped: Math.max(0, Math.min(1, value))

        height: 30 * root.s

        HoverHandler { id: shelfHover }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: shelf.label
            color: shelf.lit ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: shelf.readout
            color: shelf.lit ? Theme.cream : Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            id: shelfTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4 * root.s
            height: 3 * root.s
            radius: height / 2
            color: Theme.threadBg

            Rectangle {
                readonly property real from: shelf.bipolar ? 0.5 : 0
                x: shelfTrack.width * Math.min(from, shelf.clamped)
                width: shelfTrack.width * Math.abs(shelf.clamped - from)
                height: parent.height
                radius: parent.radius
                color: shelf.lit ? Theme.vermLit : Theme.vermDim
            }

            Rectangle {
                x: Math.max(0, Math.min(shelfTrack.width - width, shelfTrack.width * shelf.clamped - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 2.5 * root.s
                height: 10 * root.s
                radius: 2 * root.s
                color: Theme.tickRest
            }

            MouseArea {
                id: shelfDrag
                anchors.fill: parent
                anchors.margins: -8 * root.s
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function setFromX(mx) {
                    shelf.moved(Math.max(0, Math.min(1, (mx - 8 * root.s) / shelfTrack.width)));
                }
                onPressed: (e) => setFromX(e.x)
                onPositionChanged: (e) => { if (pressed) setFromX(e.x); }
                onDoubleClicked: shelf.moved(shelf.bipolar ? 0.5 : 0)
            }
        }
    }

    property bool editing: false
    property string renaming: ""
    property string aeqQuery: ""

    /** Top edge of the AutoEQ row in panel coordinates; layout deps are voided so the picker follows size changes. */
    readonly property real aeqTop: {
        void aeqRow.y;
        void aeqRow.height;
        return aeqRow.mapToItem(root, 0, 0).y;
    }

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            id: modeRow
            width: parent.width
            height: Math.max(22 * root.s, modeFlow.height)

            Flow {
                id: modeFlow
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.rightMargin: 8 * root.s
                spacing: 5 * root.s

                Repeater {
                    model: Sound.modes
                    ModeChip {}
                }

                Rectangle {
                    visible: !root.editing
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: 8 * root.s
                    color: addHover.hovered ? Theme.frameBg : "transparent"
                    border.width: 1
                    border.color: Theme.border

                    HoverHandler { id: addHover }

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: addHover.hovered ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sound.add()
                    }
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.top: parent.top
                height: 22 * root.s
                spacing: 10 * root.s

                Rectangle {
                    id: boostChip
                    anchors.verticalCenter: parent.verticalCenter
                    width: boostLabel.implicitWidth + 16 * root.s
                    height: 22 * root.s
                    radius: 8 * root.s
                    readonly property int pct: Sound.current.boost || 100
                    color: root.boostOpen ? Qt.alpha(Theme.onGlow, 0.14) : (boostArea.containsMouse ? Theme.frameBg : "transparent")
                    border.width: 1
                    border.color: root.boostOpen ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border

                    Text {
                        id: boostLabel
                        anchors.centerIn: parent
                        text: "Boost " + boostChip.pct + "%"
                        color: boostChip.pct > 100 ? Theme.vermLit : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }

                    MouseArea {
                        id: boostArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { boostMenu.visible = !boostMenu.visible; aeqPanel.close(); }
                    }
                }

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editing && Sound.dirty && Sound.currentMode !== null
                    text: "Save"
                    onClicked: Sound.save()
                }
                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editing
                    text: "Reset"
                    onClicked: Sound.restoreDefaults()
                }
                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.editing ? "Done" : "Edit"
                    color: root.editing ? Theme.vermLit : (tbHover.hovered ? Theme.cream : Theme.subtle)
                    onClicked: { root.editing = !root.editing; root.renaming = ""; }
                    HoverHandler { id: tbHover }
                }
            }
        }

        Item { width: 1; height: 10 * root.s }

        Item {
            width: parent.width
            height: bandsRow.height

            Row {
                id: barsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4 * root.s
                anchors.rightMargin: 4 * root.s
                y: 16 * root.s
                height: 70 * root.s
                spacing: 2 * root.s
                opacity: 0.32

                Repeater {
                    model: 40

                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: (barsRow.width - 39 * barsRow.spacing) / 40
                        radius: width / 2
                        height: Math.max(1, (root.levels[index] || 0) * barsRow.height)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.flameGlow }
                            GradientStop { position: 1.0; color: Theme.vermLit }
                        }
                        Behavior on height { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutQuad } }
                    }
                }
            }

            Row {
                id: bandsRow
                width: parent.width

                Repeater {
                    id: bandRep
                    model: 10
                    EqBand {}
                }
            }
        }

        Item { width: 1; height: 8 * root.s }

        Row {
            width: parent.width
            spacing: 14 * root.s

            MiniShelf {
                width: (parent.width - 28 * root.s) / 3
                label: "Bass"
                value: (Sound.current.bass + Sound.range) / (2 * Sound.range)
                readout: root.fmtDb(Sound.current.bass) + " dB"
                onMoved: (v) => Sound.setValue("bass", Math.round((v * 2 - 1) * Sound.range * 2) / 2)
            }
            MiniShelf {
                width: (parent.width - 28 * root.s) / 3
                label: "Treble"
                value: (Sound.current.treble + Sound.range) / (2 * Sound.range)
                readout: root.fmtDb(Sound.current.treble) + " dB"
                onMoved: (v) => Sound.setValue("treble", Math.round((v * 2 - 1) * Sound.range * 2) / 2)
            }
            MiniShelf {
                width: (parent.width - 28 * root.s) / 3
                label: "Widen"
                bipolar: false
                value: Sound.current.widen / 100
                readout: Math.round(Sound.current.widen) + "%"
                onMoved: (v) => Sound.setValue("widen", Math.round(v * 100))
            }
        }

        Item { width: 1; height: 10 * root.s }

        Item {
            id: aeqRow
            width: parent.width
            height: 26 * root.s

            Rectangle {
                anchors.left: parent.left
                anchors.right: nightLabel.left
                anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 26 * root.s
                radius: 8 * root.s
                color: aeqPanel.visible ? Qt.alpha(Theme.onGlow, 0.14) : (aeqHover.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: aeqPanel.visible ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                HoverHandler { id: aeqHover }

                Text {
                    id: aeqTag
                    anchors.left: parent.left
                    anchors.leftMargin: 9 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AutoEQ"
                    color: Sound.current.autoeq ? Theme.vermLit : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Bold
                }

                Text {
                    anchors.left: aeqTag.right
                    anchors.leftMargin: 8 * root.s
                    anchors.right: aeqClear.left
                    anchors.rightMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sound.current.autoeq ? Sound.current.autoeq.name : "Pick headphones"
                    elide: Text.ElideRight
                    color: Sound.current.autoeq ? Theme.cream : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Sound.current.autoeq ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        aeqPanel.toggle();
                        if (aeqPanel.visible)
                            Sound.loadAeqIndex();
                    }
                }

                GlyphIcon {
                    id: aeqClear
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11 * root.s
                    height: 11 * root.s
                    name: Sound.current.autoeq ? "close" : "chevron-up"
                    color: clearArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 2

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        hoverEnabled: true
                        enabled: Sound.current.autoeq !== undefined && Sound.current.autoeq !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sound.clearAeq()
                    }
                }
            }

            Text {
                id: nightLabel
                anchors.right: nightToggle.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "Night"
                color: nightHover.hovered ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold

                HoverHandler { id: nightHover }

                Tooltip {
                    s: root.s
                    placement: "above"
                    title: "Night mode"
                    desc: "Evens out loud and quiet parts"
                    show: nightHover.hovered
                }
            }

            LinkToggle {
                id: nightToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                on: Sound.current.night === true
                onToggled: Sound.setNight(Sound.current.night !== true)
            }
        }
    }

    /** AutoEQ picker, laid over the panel above the row so the panel height stays put. */
    Item {
        id: aeqPanel
        z: 8
        visible: false
        y: root.aeqTop - height - 6 * root.s
        anchors.right: parent.right
        width: parent.width
        height: aeqCard.height

        readonly property var results: Sound.searchAeq(root.aeqQuery)

        function toggle() { visible = !visible; }
        function close() { visible = false; root.aeqQuery = ""; }

        Rectangle {
            anchors.fill: aeqCard
            radius: aeqCard.radius
            color: Theme.cardBot
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.6
                shadowVerticalOffset: 4 * root.s
            }
        }

        Rectangle {
            id: aeqCard
            width: parent.width
            height: aeqCol.implicitHeight + 8 * root.s
            radius: 9 * root.s
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            border.width: 1
            border.color: Theme.frameBorder

            Column {
                id: aeqCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 4 * root.s

                Repeater {
                    model: aeqPanel.results

                    Rectangle {
                        id: aeqRes
                        required property var modelData
                        width: aeqCol.width
                        height: 24 * root.s
                        radius: 7 * root.s
                        color: aeqResHover.hovered ? Theme.frameBg : "transparent"

                        HoverHandler { id: aeqResHover }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.s
                            anchors.right: aeqBy.left
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: aeqRes.modelData.name
                            elide: Text.ElideRight
                            color: aeqResHover.hovered ? Theme.cream : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.Medium
                        }

                        Text {
                            id: aeqBy
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: aeqRes.modelData.by
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Sound.pickAeq(aeqRes.modelData);
                                aeqPanel.close();
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.hair; visible: aeqPanel.results.length > 0 }

                Item {
                    width: parent.width
                    height: 28 * root.s

                    TextInput {
                        id: aeqInput
                        anchors.fill: parent
                        anchors.leftMargin: 8 * root.s
                        anchors.rightMargin: 8 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.cream
                        selectionColor: Theme.verm
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        onTextChanged: root.aeqQuery = text
                        Keys.onEscapePressed: aeqPanel.close()
                        Keys.onReturnPressed: if (aeqPanel.results.length) { Sound.pickAeq(aeqPanel.results[0]); aeqPanel.close(); }
                        Connections {
                            target: aeqPanel
                            function onVisibleChanged() {
                                if (aeqPanel.visible)
                                    aeqInput.forceActiveFocus();
                            }
                        }

                        Text {
                            visible: !aeqInput.text.length
                            anchors.verticalCenter: parent.verticalCenter
                            text: Sound.aeqLoading ? "Loading the headphone list..." : (Sound.aeqError || "Search headphones, e.g. HD 600")
                            color: Theme.faint
                            font: aeqInput.font
                        }
                    }
                }
            }
        }
    }

    /** Boost picker under the top row. */
    Rectangle {
        id: boostMenu
        z: 7
        visible: false
        anchors.top: parent.top
        anchors.topMargin: modeRow.height + 4 * root.s
        anchors.right: parent.right
        width: 72 * root.s
        height: boostCol.implicitHeight + 4 * root.s
        radius: 9 * root.s
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.frameBorder

        function close() { visible = false; }

        Column {
            id: boostCol
            anchors.centerIn: parent
            width: parent.width - 4 * root.s

            Repeater {
                model: [100, 125, 150, 175, 200]

                Rectangle {
                    id: boostOpt
                    required property int modelData
                    width: boostCol.width
                    height: 24 * root.s
                    radius: 7 * root.s
                    color: boostOptHover.hovered ? Theme.frameBg
                        : ((Sound.current.boost || 100) === modelData ? Qt.alpha(Theme.onGlow, 0.16) : "transparent")

                    HoverHandler { id: boostOptHover }

                    Text {
                        anchors.centerIn: parent
                        text: boostOpt.modelData === 100 ? "Off" : boostOpt.modelData + "%"
                        color: (Sound.current.boost || 100) === boostOpt.modelData ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sound.setBoost(boostOpt.modelData);
                            boostMenu.close();
                        }
                    }
                }
            }
        }
    }
}
