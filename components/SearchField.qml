import QtQuick
import QtQuick.Controls
import "../Singletons"

Item {
    id: root

    property real s: 1
    property string kanji: ""
    property string placeholder: ""
    property string counterText: ""

    /**
     * Map Left/Right to the moved() signal instead of text-cursor motion. For a
     * horizontal result strip the arrows should page the strip; without this the
     * field swallows them until the caret sits at a text boundary, so navigation
     * stalls mid-query.
     */
    property bool horizontalNav: false
    readonly property alias input: field
    property alias text: field.text
    default property alias rightContent: rightSlot.data

    signal moved(int delta)
    signal accepted()
    signal dismissed()
    signal keyPressed(var event)

    // The root hugs the field's content height so the glyph, text, placeholder
    // and cursor all share one baseline, instead of each anchoring to a taller
    // box that drags them low. Heighting from the font metric keeps every
    // verticalCenter consistent with the typed text.
    readonly property real fieldLine: field.implicitHeight
    height: fieldLine + 2

    Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        visible: Flags.showGlyphs
        width: Flags.showGlyphs ? implicitWidth : 0
        text: root.kanji
        color: Theme.dim
        font.family: Theme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 13 * root.s
    }

    TextField {
        id: field
        anchors.left: glyph.right
        anchors.leftMargin: Flags.showGlyphs ? 10 * root.s : 0
        anchors.right: counter.left
        anchors.rightMargin: 10 * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: fieldLine
        background: null
        padding: 0
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 12.5 * root.s
        placeholderText: root.placeholder
        placeholderTextColor: Theme.faint
        selectByMouse: true
        selectionColor: Theme.verm
        cursorDelegate: Item {
            width: 2 * root.s
            height: parent.height

            property bool blinkOn: true
            Timer {
                interval: 530
                repeat: true
                running: field.activeFocus
                onTriggered: parent.blinkOn = !parent.blinkOn
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.cream
                opacity: parent.blinkOn ? 1 : 0
            }
        }
        Keys.onUpPressed: root.moved(-1)
        Keys.onDownPressed: root.moved(1)
        Keys.onPressed: (e) => {
            root.keyPressed(e);
            if (e.accepted)
                return;
            if (root.horizontalNav && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
                root.moved(e.key === Qt.Key_Right ? 1 : -1);
                e.accepted = true;
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.accepted();
                e.accepted = true;
            } else if (e.key === Qt.Key_Escape) {
                root.dismissed();
                e.accepted = true;
            }
        }
    }

    Text {
        id: counter
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: rightSlot.left
        anchors.rightMargin: rightSlot.width > 0 ? 10 * root.s : 0
        text: root.counterText
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
        font.features: { "tnum": 1 }
    }

    Item {
        id: rightSlot
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: childrenRect.width
        height: parent.height
    }
}
