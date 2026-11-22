pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"

/**
 * One tray entry: the thumbnail card, its name below it, the hover remove
 * button, and the drag-out / click / double-click handling. The strip and the
 * strip in FileTraySurface delegates to this, so the entry looks and behaves
 * the same wherever it is used and only the geometry comes from the caller.
 *
 * Drag-out starts a real OS drag (`Drag.startDrag`) carrying both text/uri-list
 * (file managers, uploads) and text/plain (editors, chat boxes). The tile never
 * moves; the drag is armed by pointer motion past a small threshold so a click
 * stays a click. Right-click removes the entry, as the hover ✕ does.
 */
Item {
    id: cell

    property real s: 1
    property string path: ""

    /**
     * Held false until the surface's open morph has settled. Decoding a
     * thumbnail and spawning a preview process both land on the GUI thread, and
     * doing either while the pill is still growing shows up as a stutter; the
     * tile shows its type glyph until the morph is done, then swaps in the art.
     */
    property bool ready: true
    /** The strip's keyboard/wheel focus; draws the ring and takes Enter. */
    property bool focused: false

    /** Raised on press so a click also moves the strip's focus here. */
    signal focusRequested()

    readonly property bool image: FileTray.isImage(cell.path)
    readonly property var preview: FileTray.previews[cell.path]
    readonly property bool previewImage: preview !== null && preview !== undefined && preview.image !== undefined
    readonly property bool previewText: preview !== null && preview !== undefined && preview.text !== undefined
    /* A local image loads straight from the source; video stills and text
     * excerpts come from the shared preview map. */
    readonly property string thumb: !cell.ready ? ""
        : (cell.previewImage ? cell.preview.image
        : (cell.image ? FileTray.uriFor(cell.path) : ""))

    readonly property real labelH: 15 * cell.s

    property bool dragging: false
    property bool dragged: false

    /* Previews spawn a process (ffmpeg for a video still, head for a text
     * excerpt), so they wait for the same settle as the thumbnail. */
    onReadyChanged: if (cell.ready) FileTray.ensurePreview(cell.path)

    /** Arm the OS drag; the tile stays put until the compositor takes over. */
    function startOutboundDrag() {
        if (dragging)
            return;
        dragging = true;
        dragged = true;
        try {
            proxy.Drag.mimeData = ({
                "text/uri-list": FileTray.uriList([cell.path]),
                "text/plain": FileTray.plainFor(cell.path)
            })
            /* Shrink the overlay's input region before the drag goes out (see
             * FileTray.dragging): the compositor hands the drag to whatever
             * surface is under the pointer. */
            FileTray.dragging = true;
            proxy.Drag.active = true;
            /* The returned action is not a success signal — Qt reports
             * IgnoreAction here even for drops the target accepted. */
            proxy.Drag.startDrag(Qt.CopyAction);
        } finally {
            FileTray.dragging = false;
            proxy.Drag.active = false;
            proxy.Drag.mimeData = ({});
            dragging = false;
        }
        dragGuard.restart();
    }

    /* A hidden proxy carries the drag, as in Ryoku's FileDragArea: the Drag
     * attached object outlives the pointer grab cleanly once there is no mouse
     * handler on the same item. */
    Item {
        id: proxy
        anchors.fill: frame
        visible: false
        Drag.dragType: Drag.None
        Drag.supportedActions: Qt.CopyAction
        Drag.proposedAction: Qt.CopyAction
        Drag.imageSource: cell.image && !FileTray.isRemote(cell.path) ? cell.thumb : ""
        Drag.imageSourceSize: Qt.size(48, 48)
        Drag.hotSpot: Qt.point(24, 24)
    }

    Rectangle {
        id: frame
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height - cell.labelH
        radius: 8 * cell.s
        color: hover.hovered ? Theme.frameBg : Qt.alpha(Theme.cream, 0.035)
        border.width: cell.focused ? 1.5 : 1
        border.color: cell.focused ? Theme.vermLit
            : (hover.hovered ? Theme.frameBorder : Theme.hair)

        Rectangle {
            id: thumb
            anchors.fill: parent
            anchors.margins: 3 * cell.s
            radius: 6 * cell.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.border
            clip: true

            Image {
                id: media
                anchors.fill: parent
                anchors.margins: 1
                visible: status === Image.Ready && cell.thumb !== ""
                source: cell.thumb
                sourceSize.width: 192
                sourceSize.height: 144
                fillMode: cell.image ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.fill: parent
                anchors.margins: 6 * cell.s
                visible: cell.previewText
                text: cell.previewText ? cell.preview.text : ""
                color: Theme.subtle
                font.family: Theme.fontMono
                font.pixelSize: 6.5 * cell.s
                lineHeight: 1.1
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                textFormat: Text.PlainText
                clip: true
            }

            GlyphIcon {
                anchors.centerIn: parent
                visible: !media.visible && !cell.previewText
                width: 24 * cell.s
                height: 24 * cell.s
                name: FileTray.glyphFor(cell.path)
                color: Theme.iconDim
                stroke: 1.6
            }
        }
    }

    Text {
        id: name
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: cell.labelH
        verticalAlignment: Text.AlignVCenter
        text: FileTray.nameOf(cell.path)
        color: hover.hovered ? Theme.cream : Theme.subtle
        font.family: Theme.font
        font.pixelSize: 10.5 * cell.s
        font.weight: Font.Medium
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Rectangle {
        id: removeBtn
        z: 2
        /* Sit inside the card, clear of the rounded outline: a 1px inset put
         * the circle straight on the border, and anchoring into the thumbnail's
         * subtree resolved against the wrong edge. 6px keeps a visible gap. */
        anchors.top: frame.top
        anchors.right: frame.right
        anchors.topMargin: 6 * cell.s
        anchors.rightMargin: 6 * cell.s
        visible: hover.hovered
        width: 16 * cell.s
        height: 16 * cell.s
        radius: width / 2
        color: removeArea.containsMouse ? Theme.verm : Theme.frameBg
        border.width: 1
        border.color: Theme.frameBorder

        GlyphIcon {
            anchors.centerIn: parent
            width: 8 * cell.s
            height: 8 * cell.s
            name: "close"
            color: removeArea.containsMouse ? Theme.cream : Theme.dim
            stroke: 2
        }

        MouseArea {
            id: removeArea
            anchors.fill: parent
            anchors.margins: -3 * cell.s
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: FileTray.remove(cell.path)
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area
        anchors.fill: parent
        /* The views are Flickables: without this the strip steals the press once
         * the pointer travels, so the tile scrolls instead of starting a drag —
         * and a stolen press also eats the click that copies. */
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        property point pressAt
        property int pressButton: Qt.NoButton

        onPressed: (mouse) => {
            pressAt = Qt.point(mouse.x, mouse.y);
            pressButton = mouse.button;
            cell.focusRequested();
        }
        onPositionChanged: (mouse) => {
            /* Only a left-button travel arms the drag; a right press is on its
             * way to removing the tile. */
            if (!pressed || pressButton !== Qt.LeftButton || cell.dragging)
                return;
            /* Manhattan travel, as in the reference implementations: a couple of
             * pixels of hand tremor stays a click. */
            if (Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y) < 8 * cell.s)
                return;
            cell.startOutboundDrag();
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                FileTray.remove(cell.path);
                return;
            }
            if (cell.dragged)
                return;
            FileTray.copy(cell.path);
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && !cell.dragged)
                FileTray.open(cell.path);
        }
    }

    Timer {
        id: dragGuard
        interval: 250
        onTriggered: cell.dragged = false
    }
}
