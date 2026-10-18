pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * A setting's choice chip. It does not drop a menu of its own: opening it hands
 * the choice to the centred `Selector` picker, so every selector in the pill and
 * the dock — display, theme, dock, wallpaper, lock — is the same transient card
 * in the middle of the screen, gone the moment a value is picked.
 *
 * The host still owns open/close (`open`, `chipClicked`) and receives the result
 * through `picked(value)`; `moveSel`/`pickSel` remain the keyboard entry points
 * the wallpaper strip and the row registry already call. The chip shows the
 * current label, or a `glyph` icon instead when one is set.
 *
 * `options` is a list of `{ label, value, icon? }`; an optional `icon` is drawn
 * in the picker beside the label. The picker is hosted once per window, so the
 * chip reports which window it belongs to (`hostKey`), found by walking up to the
 * nearest ancestor naming one — the pill carries `pill:<monitor>` and the dock's
 * panel `dock:<monitor>`.
 */
Item {
    id: root

    required property var options
    property var value: ""
    /** The host's SettingsPalette; a null one means the pill's own Theme
     * tokens. The dock's settings panel passes the dock's palette, so the chip
     * takes the dock's colours and not the pill's. */
    property var pal: null
    property string glyph: ""
    property string title: ""
    property string desc: ""
    property bool open: false
    property real s: 1

    signal picked(var value)
    signal chipClicked()

    /**
     * What the centred picker calls this choice. `title` when the host set one
     * (the wallpaper strip does, for its captions); otherwise the enclosing
     * settings row's name, found the same way `hostKey` finds the window, so a
     * row like "Time format" names the card without every call site repeating
     * itself.
     */
    readonly property string pickerTitle: {
        if (root.title.length > 0)
            return root.title;
        var p = root.parent;
        while (p) {
            if (p.name !== undefined && String(p.name).length > 0)
                return String(p.name);
            p = p.parent;
        }
        return "";
    }

    readonly property int curIndex: {
        for (var i = 0; i < options.length; i++)
            if (String(options[i].value) === String(root.value))
                return i;
        return -1;
    }

    readonly property string curLabel: curIndex >= 0 ? options[curIndex].label : ""

    readonly property color chipGlyph: root.pal ? root.pal.sub : Theme.iconDim
    readonly property color chipInk: root.pal ? root.pal.sub : Theme.subtle
    readonly property color chipTile: root.pal ? root.pal.tile : Theme.frameBg
    readonly property color chipActive: root.pal ? root.pal.accent : Theme.vermLit

    readonly property real chipH: 22 * root.s

    /**
     * The window this chip reports to: the first ancestor that names one. The
     * picker is drawn per window (the pill's overlay, the dock's), and this is
     * how the right one knows the choice is its own.
     */
    function hostKey() {
        var p = root.parent;
        while (p) {
            if (p.pickerKey !== undefined)
                return p.pickerKey;
            p = p.parent;
        }
        return "";
    }

    onOpenChanged: {
        if (root.open)
            Selector.show({ title: root.pickerTitle, options: root.options, value: root.value, tag: root, owner: root.hostKey() });
        else if (Selector.open && Selector.tag === root)
            Selector.close();
    }

    Connections {
        target: Selector

        function onPicked(value, tag) {
            if (tag === root)
                root.picked(value);
        }

        /** The picker closing by any other route (scrim, Escape) closes the chip. */
        function onOpenChanged() {
            if (!Selector.open && root.open && Selector.tag === root)
                root.open = false;
        }

        /** A second selector opening takes the picker over: stand down. */
        function onTagChanged() {
            if (root.open && Selector.tag !== root)
                root.open = false;
        }
    }

    function moveSel(dir) {
        if (Selector.tag === root)
            Selector.move(dir);
    }

    function pickSel() {
        if (Selector.tag === root)
            Selector.activate();
    }

    width: chip.width
    height: chip.height

    Rectangle {
        id: chip
        width: iconGlyph.visible ? root.chipH : chipLabel.implicitWidth + 15 * root.s
        height: root.chipH
        radius: height / 2
        /** While the picker this chip opened is up, the chip keeps a shade: the
         * card is in the middle of the screen, and the shade is what ties it
         * back to the control it came from. */
        color: root.open ? Qt.alpha(root.chipActive, 0.16)
             : (chipHover.hovered ? root.chipTile : "transparent")
        border.width: 0
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        GlyphIcon {
            id: iconGlyph
            anchors.centerIn: parent
            visible: root.glyph.length > 0
            width: 13 * root.s
            height: 13 * root.s
            name: root.glyph
            color: root.open ? root.chipActive : root.chipGlyph
            stroke: 1.8
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Text {
            id: chipLabel
            anchors.centerIn: parent
            visible: root.glyph.length === 0
            text: root.curLabel
            color: root.open ? root.chipActive : root.chipInk
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            font.weight: Font.DemiBold
        }

        HoverHandler {
            id: chipHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chipClicked()
        }

        Tooltip {
            placement: "below"
            align: "right"
            title: root.title
            desc: root.desc
            show: chipHover.hovered && !root.open && (root.title.length > 0 || root.desc.length > 0)
        }
    }
}
