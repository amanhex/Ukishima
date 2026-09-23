import QtQuick
import QtQuick.Effects
import "../Singletons"

/**
 * Washi hint bubble for pill controls. Anchored to its parent control;
 * `placement` decides whether the bubble floats above (pointer down) or below
 * (pointer up), and `align` whether its left/right edge or centre lines up
 * with the control, so bubbles near the pill edge never clip off-screen. The
 * host sets `show` from the control's own HoverHandler; the bubble arms after
 * a hover delay, fades in slowly and out fast.
 *
 * Non-interactive by design: no MouseArea or HoverHandler lives here, so it
 * never steals pointer events from the controls or the mixer's hover tracker.
 * It is `visible: false` whenever fully faded, for the same reason.
 */
Item {
    id: root

    property real s: 1
    property string title: ""
    property string desc: ""
    property bool show: false
    property string placement: "above"
    property string align: "center"

    readonly property bool below: placement === "below"
    readonly property real pointerH: 5 * s
    readonly property real gap: 5 * s

    property bool armed: false

    width: bubble.width
    height: bubble.height + pointerH
    z: 20

    anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
    anchors.left: root.align === "left" ? parent.left : undefined
    anchors.right: root.align === "right" ? parent.right : undefined
    anchors.bottom: below ? undefined : parent.top
    anchors.bottomMargin: below ? 0 : gap
    anchors.top: below ? parent.bottom : undefined
    anchors.topMargin: below ? gap : 0

    visible: armed || opacity > 0.01
    opacity: armed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.armed ? Motion.standard : Motion.fast } }

    Timer {
        id: delay
        interval: 470
        onTriggered: root.armed = true
    }
    onShowChanged: {
        if (show) {
            delay.restart();
        } else {
            delay.stop();
            armed = false;
        }
    }

    Rectangle {
        id: bubble
        anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
        anchors.left: root.align === "left" ? parent.left : undefined
        anchors.right: root.align === "right" ? parent.right : undefined
        anchors.top: root.below ? undefined : parent.top
        anchors.bottom: root.below ? parent.bottom : undefined
        width: Math.max(titleText.implicitWidth, descText.implicitWidth) + 22 * root.s
        height: column.implicitHeight + 14 * root.s
        radius: 9 * root.s
        border.width: 1
        border.color: Theme.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        /**
         * Contrast veil: a solid bubble must read against the translucent glass
         * and the wallpaper behind it, so the fill is deepened a notch past the
         * plain card gradient. Kept 1px inside the border so the hairline stays
         * crisp; keeps cream copy legible in both palettes.
         */
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: Qt.rgba(0, 0, 0, 0.22)
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.7)
            shadowBlur: 0.7
            shadowVerticalOffset: 5 * root.s
        }
    }

    Column {
        id: column
        anchors.centerIn: bubble
        spacing: 2 * root.s

        Text {
            id: titleText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.title
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Bold
        }
        Text {
            id: descText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.desc.length > 0
            text: root.desc
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
        }
    }

    Canvas {
        width: 11 * root.s
        height: root.pointerH
        anchors.horizontalCenter: root.align === "center" ? parent.horizontalCenter : undefined
        anchors.left: root.align === "left" ? parent.left : undefined
        anchors.right: root.align === "right" ? parent.right : undefined
        anchors.top: root.below ? parent.top : undefined
        anchors.bottom: root.below ? undefined : parent.bottom
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            /* Match the bubble's bottom under its contrast veil: cardBot mixed
             * 22% toward black, same as the fill rectangle above. */
            var c = Theme.cardBot;
            ctx.fillStyle = Qt.rgba(c.r * 0.78, c.g * 0.78, c.b * 0.78, 1);
            ctx.beginPath();
            if (root.below) {
                ctx.moveTo(0, height);
                ctx.lineTo(width, height);
                ctx.lineTo(width / 2, 0);
            } else {
                ctx.moveTo(0, 0);
                ctx.lineTo(width, 0);
                ctx.lineTo(width / 2, height);
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
