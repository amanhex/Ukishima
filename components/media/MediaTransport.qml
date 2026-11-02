pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."
import "../../Singletons"

/**
 * Transport chips for the Chaldea-style media designs: PREV / PLAY-PAUSE / NEXT
 * in the reference's squared mono style, switching to the pill's kanji labels
 * when Japanese glyphs are on. `host` is the Media surface.
 */
GridLayout {
    id: transport

    property var host: null
    property bool vertical: false
    property bool compact: false
    readonly property real s: transport.host ? transport.host.s : 1

    columns: transport.vertical ? 1 : 3
    columnSpacing: 4 * transport.s
    rowSpacing: 3 * transport.s

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool active: false
        property bool primary: false
        property bool can: true
        signal activated()

        readonly property bool hovered: chipHover.hovered

        implicitWidth: Math.max((transport.compact ? 22 : 28) * transport.s, chipLabel.implicitWidth + 10 * transport.s)
        implicitHeight: (transport.compact ? 15 : 18) * transport.s
        color: chip.active ? Theme.accent : (chip.hovered ? Theme.cardTop : Theme.cardBot)
        border.width: 1
        border.color: chip.primary ? Theme.accent : Qt.alpha(Theme.cream, 0.22)
        opacity: chip.can ? 1 : 0.35

        Behavior on color { ColorAnimation { duration: Motion.fast } }

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: Theme.cream
            font.family: Flags.showGlyphs && chip.label.length === 1 ? Theme.fontJp : Theme.fontMono
            font.pixelSize: (transport.compact ? 8 : 9) * transport.s
            font.weight: chip.active ? Font.Bold : Font.Normal
        }

        HoverHandler { id: chipHover }

        MouseArea {
            anchors.fill: parent
            enabled: chip.can
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    Chip {
        label: Flags.showGlyphs ? "前" : "PREV"
        can: transport.host && transport.host.hasPlayer && transport.host.player.canGoPrevious
        onActivated: transport.host.player.previous()
    }

    Chip {
        label: Flags.showGlyphs ? (transport.host && transport.host.playing ? "休" : "奏")
                                : (transport.host && transport.host.playing ? "PAUSE" : "PLAY")
        active: transport.host ? transport.host.playing : false
        primary: true
        can: transport.host && transport.host.hasPlayer && transport.host.player.canTogglePlaying
        onActivated: transport.host.player.togglePlaying()
    }

    Chip {
        label: Flags.showGlyphs ? "次" : "NEXT"
        can: transport.host && transport.host.hasPlayer && transport.host.player.canGoNext
        onActivated: transport.host.player.next()
    }
}
