pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * One note row for the list-shaped scratchpad designs (cassette, index,
 * console). Draws the number, title, pin, age and an optional preview line;
 * the hosting list owns selection, hover and the click. `host` is Scratchpad.
 */
Item {
    id: row

    property var host: null
    property int number: 0
    property bool numbered: true
    property string title: ""
    property string preview: ""
    property string age: ""
    property bool pinned: false
    property bool selected: false
    property bool hovered: false
    property bool monoTitle: false
    property bool showPreview: true
    property bool marker: true
    readonly property real s: row.host ? row.host.s : 1

    Rectangle {
        anchors.fill: parent
        color: row.selected ? Qt.alpha(Theme.vermLit, 0.10)
            : row.hovered ? Qt.alpha(Theme.cream, 0.045) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2 * row.s
        visible: row.selected
        color: Theme.vermLit
    }

    Rectangle {
        visible: row.marker && row.selected
        anchors.left: parent.left
        anchors.leftMargin: 12 * row.s
        anchors.top: parent.top
        anchors.topMargin: 9 * row.s
        width: 4 * row.s
        height: 4 * row.s
        rotation: 45
        color: Theme.vermLit
    }

    Text {
        id: num
        anchors.left: parent.left
        anchors.leftMargin: (row.marker ? 22 : 12) * row.s
        anchors.top: parent.top
        anchors.topMargin: 9 * row.s
        visible: row.numbered
        width: row.numbered ? 24 * row.s : 0
        text: row.numbered ? String(row.number).padStart(2, "0") : ""
        color: Theme.faint
        font.family: Theme.fontMono
        font.pixelSize: 8 * row.s
        font.features: { "tnum": 1 }
    }

    Text {
        id: name
        anchors.left: num.right
        anchors.leftMargin: row.numbered ? 8 * row.s : 0
        anchors.right: meta.left
        anchors.rightMargin: 10 * row.s
        anchors.top: parent.top
        anchors.topMargin: 7 * row.s
        text: row.title
        color: Theme.cream
        elide: Text.ElideRight
        font.family: row.monoTitle ? Theme.fontMono : Theme.font
        font.pixelSize: 11.5 * row.s
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
    }

    Row {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: 12 * row.s
        anchors.top: parent.top
        anchors.topMargin: 9 * row.s
        spacing: 5 * row.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.pinned
            width: 8 * row.s
            height: 8 * row.s
            name: "pin"
            stroke: 1.8
            color: Theme.vermLit
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.age
            color: Theme.faint
            font.family: Theme.fontMono
            font.pixelSize: 8 * row.s
            font.features: { "tnum": 1 }
        }
    }

    Text {
        visible: row.showPreview
        anchors.left: name.left
        anchors.right: parent.right
        anchors.rightMargin: 12 * row.s
        anchors.top: name.bottom
        anchors.topMargin: 3 * row.s
        text: row.preview.length > 0 ? row.preview : "empty"
        color: row.preview.length > 0 ? Theme.subtle : Theme.faint
        elide: Text.ElideRight
        font.family: Theme.fontMono
        font.pixelSize: 9 * row.s
    }
}
