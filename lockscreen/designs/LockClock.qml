import QtQuick

/**
 * Date + time for the lock designs. `host` supplies the 12/24h choice from the
 * shared flags; colours and size are the design's business.
 */
Item {
    id: root

    property var host: null
    property real timeSize: 92
    property real dateSize: 11
    property bool showDate: true
    property bool alignLeft: false
    property color ink: "#e4e2dc"
    property color muted: "#98948a"
    property color accent: "#d1161c"
    property bool accentColon: false
    readonly property bool isSharpCapture: root.host ? (root.host.background === "capture" && root.host.blurMax <= 16) : false

    readonly property string timeText: {
        const d = clock.now;
        return Qt.formatTime(d, root.host && root.host.use12h ? "h:mm AP" : "HH:mm");
    }
    readonly property string dateText: clock.now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")

    implicitWidth: Math.max(dateLabel.implicitWidth, timeLabel.implicitWidth)
    implicitHeight: (root.showDate ? dateLabel.implicitHeight + 3 : 0) + timeLabel.implicitHeight

    Text {
        id: dateLabel

        visible: root.showDate
        width: root.width
        text: root.dateText.toUpperCase()
        color: root.muted
        font.family: "JetBrainsMono NF"
        font.pixelSize: root.dateSize
        font.letterSpacing: 1.2
        horizontalAlignment: root.alignLeft ? Text.AlignLeft : Text.AlignHCenter
        renderType: Text.NativeRendering
        style: root.isSharpCapture ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.75)
    }

    Text {
        id: timeLabel

        y: root.showDate ? dateLabel.implicitHeight + 3 : 0
        width: root.width
        text: root.timeText
        color: root.ink
        font.family: "JetBrainsMono NF"
        font.pixelSize: root.timeSize
        font.weight: Font.Medium
        font.letterSpacing: -root.timeSize * 0.035
        horizontalAlignment: root.alignLeft ? Text.AlignLeft : Text.AlignHCenter
        renderType: Text.NativeRendering
        style: root.isSharpCapture ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.75)
    }

    QtObject {
        id: clock

        property var now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    //* Repaint the date at midnight without waiting a day on a stale label.
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }
}