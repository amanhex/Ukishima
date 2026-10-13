pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * One settings line: an optional leading kanji, a name and an optional faint sub
 * caption on the left, and a control slot on the right, capped by a single bottom
 * hairline. `control` is the default slot for the toggle, segmented control or
 * chevron. `surface` wires hover and activation back to the owning settings
 * surface so the soul seam tracks the focused row; scale derives from it.
 *
 * Colours come from the surface's `pal` (see SettingsPalette), so the same row
 * renders in the pill or in the dock's own settings panel without either host
 * borrowing the other's palette. The `Theme` fallbacks below only apply to a row
 * used with no surface at all.
 */
Item {
    id: srow

    property var surface: null
    property string glyph: ""
    property string icon: ""
    property string name: ""
    property string sub: ""
    property bool last: false
    property bool captionOnFocus: false
    default property alias control: controlSlot.data

    readonly property real s: srow.surface ? srow.surface.s : 1
    readonly property bool focused: srow.surface ? srow.surface.focusRowItem === srow : false

    /** The host's palette. Every colour below resolves through it. */
    readonly property var pal: srow.surface ? srow.surface.pal : null
    readonly property color ink: srow.pal ? srow.pal.ink : Theme.cream
    readonly property color subInk: srow.pal ? srow.pal.sub : Theme.subtle
    readonly property color faint: srow.pal ? srow.pal.faint : Theme.faint
    readonly property color iconIdle: srow.pal ? srow.pal.sub : Theme.iconDim
    readonly property color tile: srow.pal ? srow.pal.tile : Theme.frameBg
    readonly property color hair: srow.pal ? srow.pal.hair : Theme.hairSoft

    width: parent ? parent.width : 0
    height: Math.max(textCol.implicitHeight, controlSlot.childrenRect.height) + 12 * srow.s

    /**
     * While a control with an `open` state (a Dropdown) is open, the row's
     * whole subtree rides above the rows below so the menu card floats like the
     * wallpaper strip's — a menu nested at row depth would otherwise paint
     * under its siblings and arrive looking cut up.
     */
    readonly property bool controlOpen: {
        for (var i = 0; i < controlSlot.children.length; i++)
            if (controlSlot.children[i].open)
                return true;
        return false;
    }
    z: srow.controlOpen ? 10 : 0

    HoverHandler {
        id: srowHover
        onHoveredChanged: if (srow.surface) srow.surface.reportRowHover(srow, hovered)
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3 * srow.s
        anchors.bottomMargin: 3 * srow.s
        radius: 9 * srow.s
        color: (srowHover.hovered || srow.focused) ? srow.tile : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (srow.surface) srow.surface.activateRow(srow)
    }

    Text {
        id: rk
        anchors.left: parent.left
        anchors.leftMargin: 12 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        visible: srow.glyph.length > 0 && srow.icon.length === 0 && Flags.showGlyphs
        text: srow.glyph
        color: srow.iconIdle
        font.family: Theme.fontJp
        font.weight: Theme.fontJpWeight
        font.pixelSize: 15 * srow.s
    }

    GlyphIcon {
        id: ri
        anchors.left: parent.left
        anchors.leftMargin: 14 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        visible: srow.icon.length > 0
        width: 17 * srow.s
        height: 17 * srow.s
        name: srow.icon
        color: srow.focused ? srow.ink : srow.subInk
        stroke: 1.8
    }

    Column {
        id: textCol
        anchors.left: ri.visible ? ri.right : (rk.visible ? rk.right : parent.left)
        anchors.leftMargin: ri.visible ? 13 * srow.s : (rk.visible ? 11 * srow.s : 12 * srow.s)
        anchors.right: controlSlot.left
        anchors.rightMargin: 14 * srow.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * srow.s

        Text {
            text: srow.name
            width: parent.width
            elide: Text.ElideRight
            color: srow.ink
            font.family: Theme.font
            font.pixelSize: 12.5 * srow.s
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            visible: srow.sub.length > 0 && (!srow.captionOnFocus || srow.focused || srowHover.hovered)
            text: srow.sub
            color: srow.faint
            font.family: Theme.font
            font.pixelSize: 10.5 * srow.s
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }

    Item {
        id: controlSlot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: implicitHeight
        implicitHeight: {
            var h = 0;
            for (var i = 0; i < children.length; i++) {
                var c = children[i];
                if (c.height > h) h = c.height;
            }
            return h;
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: srow.hair
        visible: !srow.last
    }
}