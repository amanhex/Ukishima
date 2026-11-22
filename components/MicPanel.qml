import QtQuick
import "../Singletons"

/** Mic tab of the mixer: a single fader for the default input's live Pipewire gain. */
Item {
    id: root

    property real s: 1

    implicitHeight: 26 * root.s

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 52 * root.s
        text: "Volume"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 9.5 * root.s
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.6 * root.s
    }

    HFader {
        anchors.left: label.right
        anchors.leftMargin: 10 * root.s
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        s: root.s
        readonly property real vol: Sound.source && Sound.source.audio ? Sound.source.audio.volume : 0
        value: vol / 2
        readout: Math.round(vol * 100) + "%"
        focused: micHover.hovered
        onMoved: (v) => Sound.setNodeVolume(Sound.source, Math.round(v * 200) / 100, "micvol", "Mic volume")
        HoverHandler { id: micHover }
    }
}
