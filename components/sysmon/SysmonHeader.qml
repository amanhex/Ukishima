pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../Singletons"

/**
 * Chaldea-style sysmon header: the 系 tag, a mono wordmark and the uptime on
 * the right. `soulPoint` is the design-local spot the surface's soul ember
 * docks to, mapped by the host. `host` is SysmonSurface.
 */
Item {
    id: head

    property var host: null
    property string tag: "系"
    property string wordmark: "SYSTEM"
    property string trailing: ""
    property color accent: Theme.vermLit
    readonly property real s: head.host ? head.host.s : 1

    implicitHeight: 20 * head.s

    Row {
        id: left
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * head.s

        Text {
            id: tagText
            visible: Flags.showGlyphs
            text: head.tag
            color: head.accent
            font.family: Theme.fontJp
            font.weight: Theme.fontJpWeight
            font.pixelSize: 15 * head.s
        }
        Text {
            id: word
            text: head.wordmark
            color: Theme.cream
            font.family: Theme.fontMono
            font.pixelSize: 9 * head.s
            font.letterSpacing: 1.4
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: head.trailing.length > 0 ? head.trailing : Sysmon.uptime
        color: Theme.dim
        font.family: Theme.fontMono
        font.pixelSize: 8.5 * head.s
        font.letterSpacing: 0.8
        font.features: { "tnum": 1 }
    }

    readonly property point soulPoint: {
        var a = tagText.visible ? tagText : word;
        return a.mapToItem(head, a.width / 2, -2 * head.s);
    }
}
