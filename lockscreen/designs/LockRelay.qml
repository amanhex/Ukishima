import QtQuick
import ".."

/**
 * Relay — a vertical wordmark on the left, the clock and password field in the
 * middle, and the compound glyph in a bay on the right. Adapted from Chaldea's
 * relay-index study; the media card, wifi and battery stay live.
 */
Item {
    id: root

    property var host: null

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 1000 * root.s
    readonly property color ink: "#e4e2dc"
    readonly property color muted: "#98948a"
    readonly property color accent: "#d1161c"
    readonly property color line: "#393630"

    Item {
        id: furniture

        anchors.fill: parent
        opacity: root.host ? root.host.stage(40 / 380, 320 / 380, 1) * root.host.held : 0

        Item {
            id: header

            x: 32 * root.s
            y: 27 * root.s
            width: parent.width - x * 2
            height: 30 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14 * root.s

                Text {
                    text: "UKISHIMA"
                    color: root.ink
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.2 * root.s
                }

                Text {
                    text: "//"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                }

                Text {
                    text: "TYPE-17"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 76 * root.s
                height: 30 * root.s
                color: root.accent

                Text {
                    anchors.centerIn: parent
                    text: "◆ 704"
                    color: "#090909"
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 13 * root.s
                    font.letterSpacing: 2 * root.s
                }
            }
        }

        Item {
            id: titleCol

            visible: !root.narrow
            x: 32 * root.s
            y: Math.max(header.y + header.height + 54 * root.s, parent.height * 0.20)
            width: 150 * root.s
            height: 420 * root.s

            Rectangle {
                width: 3 * root.s
                height: parent.height
                color: root.accent
            }

            Text {
                x: 15 * root.s
                text: "L\nI\nN\nK"
                color: root.ink
                font.family: "JetBrainsMono NF"
                font.pixelSize: 78 * root.s
                font.weight: Font.DemiBold
                lineHeightMode: Text.FixedHeight
                lineHeight: 112 * root.s
            }

            Text {
                x: 15 * root.s
                y: 300 * root.s
                text: "鍵"
                color: root.ink
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 24 * root.s
                font.letterSpacing: 5 * root.s
            }

            Text {
                x: 15 * root.s
                y: 340 * root.s
                text: "UKISHIMA / 17"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1.2 * root.s
            }
        }

        LockClock {
            id: clock

            host: root.host
            x: root.narrow ? (parent.width - width) / 2 : 214 * root.s
            y: root.narrow ? header.y + header.height + 54 * root.s : Math.max(header.y + header.height + 90 * root.s, parent.height * 0.25)
            width: root.narrow ? Math.min(parent.width - 64 * root.s, 360 * root.s) : 360 * root.s
            timeSize: (root.narrow ? 56 : 62) * root.s
            dateSize: 10 * root.s
            alignLeft: !root.narrow
            ink: root.ink
            muted: root.muted
            accent: root.accent
        }

        LockIdentity {
            id: identity

            host: root.host
            x: root.narrow ? (parent.width - width) / 2 : 214 * root.s
            y: clock.y + clock.height + 20 * root.s
            width: root.narrow ? 200 * root.s : 240 * root.s
            avatarSize: 44 * root.s
            horizontal: true
            ink: root.ink
            muted: root.muted
        }

        LockField {
            id: field

            host: root.host
            x: root.narrow ? (parent.width - width) / 2 : 214 * root.s
            y: identity.y + identity.height + 12 * root.s
            width: root.narrow ? Math.min(parent.width - 64 * root.s, 360 * root.s) : 360 * root.s
            ink: root.ink
            muted: root.muted
            accent: root.accent
            line: root.line
            ground: "#090909"
        }

        Item {
            id: bay

            visible: !root.narrow
            width: Math.min(330 * root.s, parent.width * 0.20)
            height: width + 42 * root.s
            x: parent.width - width - 40 * root.s
            y: Math.max(header.y + header.height + 70 * root.s, parent.height * 0.24)

            LockGlyph {
                host: root.host
                width: parent.width
                height: parent.width
                phase: root.host ? root.host.context.currentText.length : 0
            }

            Rectangle {
                y: parent.width + 12 * root.s
                width: parent.width
                height: 1
                color: root.line
            }

            Text {
                y: parent.width + 22 * root.s
                text: "A"
                color: root.accent
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1 * root.s
            }

            Text {
                anchors.right: parent.right
                y: parent.width + 22 * root.s
                text: "RELAY TILES"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1 * root.s
            }
        }

        LockMediaSlot {
            id: media

            host: root.host
            variant: "relay"
            amount: 0.9 * root.s
            x: root.narrow ? (parent.width - width) / 2 : 214 * root.s
            y: field.y + field.height + Math.max(20, 26 * root.s)
        }

        LockWifi {
            anchors.left: parent.left
            anchors.leftMargin: 32 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26 * root.s
            visible: root.host ? root.host.showWifi && wifiDev !== null : false
        }

        LockBattery {
            anchors.right: parent.right
            anchors.rightMargin: 32 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26 * root.s
            shimmerOn: root.host ? root.host.batteryShimmerOn : false
            visible: root.host ? root.host.showBattery && present : false
        }
    }
}