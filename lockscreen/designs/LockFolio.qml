import QtQuick
import ".."

/**
 * Folio — a typographic title block, a centred glyph bay and the login column
 * on the right. Adapted from Chaldea's type-folio study.
 */
Item {
    id: root

    property var host: null

    function stage(from, to, peak) {
        return root.host ? root.host.stage(from, to, peak) : 0;
    }

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 1000 * root.s
    readonly property color ink: "#e4e2dc"
    readonly property color paper: "#0b0a09"
    readonly property color muted: "#98948a"
    readonly property color accent: "#d1161c"
    readonly property color line: "#393630"

    Item {
        id: furniture

        anchors.fill: parent
        opacity: root.host ? root.host.held : 0

        Rectangle {
            anchors.fill: parent
            color: root.paper
            opacity: 0.55
        }

        Item {
            id: header

            opacity: root.stage(0, 0.30, 1)
            x: 32 * root.s
            y: 27 * root.s
            width: parent.width - x * 2
            height: 30 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15 * root.s

                Text {
                    text: "UKISHIMA"
                    color: root.ink
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.6 * root.s
                }

                Text {
                    text: "//"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                }

                Text {
                    text: "FOLIO"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 68 * root.s
                height: 28 * root.s
                color: root.accent

                Text {
                    anchors.centerIn: parent
                    text: "◆ 15"
                    color: root.paper
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 12 * root.s
                    font.letterSpacing: 1.6 * root.s
                }
            }
        }

        Item {
            id: title

            opacity: root.stage(0.06, 0.38, 1)

            transform: Translate {
                y: -14 * (1 - root.stage(0.06, 0.42, 1))
            }

            x: root.narrow ? 32 * root.s : 48 * root.s
            y: root.narrow ? header.y + header.height + 40 * root.s : Math.max(header.y + header.height + 80 * root.s, parent.height * 0.20)
            width: root.narrow ? parent.width - 64 * root.s : 220 * root.s
            height: root.narrow ? 132 * root.s : 220 * root.s

            Text {
                text: "Type 17"
                color: root.ink
                font.family: "Noto Serif"
                font.pixelSize: (root.narrow ? 48 : 58) * root.s
                font.letterSpacing: -1.5 * root.s
            }

            Text {
                y: 64 * root.s
                text: "鍵"
                color: root.ink
                font.family: "Noto Serif CJK JP"
                font.pixelSize: (root.narrow ? 30 : 40) * root.s
                font.letterSpacing: 6 * root.s
            }

            Text {
                y: (root.narrow ? 110 : 132) * root.s
                text: "UKISHIMA / 15"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1.1 * root.s
            }

            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: root.line
            }
        }

        Item {
            id: bay

            opacity: root.stage(0.12, 0.44, 1)

            transform: Translate {
                y: -16 * (1 - root.stage(0.12, 0.48, 1))
            }

            visible: !root.narrow
            width: Math.min(340 * root.s, parent.width * 0.24)
            height: width + 42 * root.s
            x: 320 * root.s
            y: Math.max(header.y + header.height + 66 * root.s, parent.height * 0.22)

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

        LockClock {
            id: clock

            opacity: root.stage(0.15, 0.47, 1)

            transform: Translate {
                y: -22 * (1 - root.stage(0.15, 0.52, 1))
            }

            host: root.host
            x: root.narrow ? (parent.width - width) / 2 : 48 * root.s
            y: root.narrow ? title.y + title.height + 20 * root.s : parent.height * 0.58
            width: root.narrow ? Math.min(parent.width - 64 * root.s, 340 * root.s) : 220 * root.s
            timeSize: (root.narrow ? 54 : 70) * root.s
            dateSize: 10 * root.s
            alignLeft: !root.narrow
            ink: root.ink
            muted: root.muted
        }

        Item {
            id: entry

            opacity: root.stage(0.24, 0.56, 1)

            transform: Translate {
                y: 24 * (1 - root.stage(0.24, 0.60, 1))
            }

            x: root.narrow ? (parent.width - width) / 2 : parent.width - width - 48 * root.s
            y: root.narrow ? clock.y + clock.height + 18 * root.s : parent.height * 0.52
            width: root.narrow ? Math.min(parent.width - 64 * root.s, 340 * root.s) : 300 * root.s
            height: identity.height + 14 * root.s + 44

            LockIdentity {
                id: identity

                host: root.host
                width: parent.width
                avatarSize: 40 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                y: identity.height + 14 * root.s
                width: parent.width
                host: root.host
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: root.paper
            }
        }

        LockMediaSlot {
            id: media

            opacity: root.stage(0.36, 0.64, 1)

            transform: Translate {
                y: 14 * (1 - root.stage(0.36, 0.68, 1))
            }

            host: root.host
            variant: "folio"
            amount: 0.78 * root.s
            x: root.narrow ? (parent.width - width) / 2 : parent.width - width - 48 * root.s
            y: entry.y + entry.height + Math.max(20, 26 * root.s)
        }

        LockWifi {
            anchors.left: parent.left
            anchors.leftMargin: 32 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24 * root.s
            opacity: root.stage(0.30, 0.58, 1)
            visible: root.host ? root.host.showWifi && wifiDev !== null : false
        }

        LockBattery {
            anchors.right: parent.right
            anchors.rightMargin: 32 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24 * root.s
            opacity: root.stage(0.30, 0.58, 1)
            shimmerOn: root.host ? root.host.batteryShimmerOn : false
            visible: root.host ? root.host.showBattery && present : false
        }
    }
}