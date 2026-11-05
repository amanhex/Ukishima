import QtQuick
import ".."

/**
 * Phase — a centred login panel with a red folio spine, the compound glyph
 * behind it, clock above and the media card below. Adapted from Chaldea's
 * phase-lock formation.
 */
Item {
    id: root

    property var host: null

    function stage(from, to, peak) {
        return root.host ? root.host.stage(from, to, peak) : 0;
    }

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 820 * root.s
    readonly property color ink: "#e4e2dc"
    readonly property color muted: "#98948a"
    readonly property color accent: "#d1161c"
    readonly property color line: "#393630"
    readonly property color ground: "#090909"

    Item {
        id: furniture

        anchors.fill: parent
        opacity: root.host ? root.host.held : 0

        LockGlyph {
            host: root.host
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.52, parent.height * 0.62)
            height: width
            opacity: 0.22 * root.stage(0, 0.30, 1)
            showGround: false
            phase: root.host ? root.host.context.currentText.length : 0
        }

        Item {
            id: header

            opacity: root.stage(0, 0.30, 1)
            x: 32 * root.s
            y: 26 * root.s
            width: parent.width - x * 2
            height: 26 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "UKISHIMA // PHASE"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1.6 * root.s
            }
        }

        LockClock {
            id: clock

            opacity: root.stage(0.15, 0.47, 1)

            transform: Translate {
                y: -22 * (1 - root.stage(0.15, 0.52, 1))
            }

            host: root.host
            x: (parent.width - width) / 2
            y: Math.max(header.y + header.height + 54 * root.s, parent.height * 0.18)
            width: Math.min(parent.width - 64 * root.s, 380 * root.s)
            timeSize: (root.narrow ? 54 : 64) * root.s
            dateSize: 10 * root.s
            ink: root.ink
            muted: root.muted
        }

        Item {
            id: panel

            opacity: root.stage(0.24, 0.56, 1)

            transform: Translate {
                y: 24 * (1 - root.stage(0.24, 0.60, 1))
            }

            anchors.horizontalCenter: parent.horizontalCenter
            y: clock.y + clock.height + 28 * root.s
            width: Math.min(root.narrow ? parent.width - 48 * root.s : 500 * root.s, parent.width - 48 * root.s)
            height: 214 * root.s

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(9 / 255, 9 / 255, 9 / 255, 0.66)
                border.color: root.line
                border.width: 1
            }

            Rectangle {
                id: folio

                x: 1
                y: 1
                width: (root.narrow ? 58 : 78) * root.s
                height: parent.height - 2
                color: root.accent

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18 * root.s
                    text: root.narrow ? "TYPE-17" : "T\nY\nP\nE"
                    color: "#140a09"
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1 * root.s
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 15 * root.s
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.centerIn: parent
                    text: "継\n衛"
                    color: "#140a09"
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: (root.narrow ? 28 : 38) * root.s
                    lineHeightMode: Text.FixedHeight
                    lineHeight: (root.narrow ? 34 : 44) * root.s
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 36 * root.s
                    width: parent.width - 18 * root.s
                    height: 22 * root.s
                    color: "#140a09"

                    Text {
                        anchors.centerIn: parent
                        text: "704"
                        color: root.accent
                        font.family: "JetBrainsMono NF"
                        font.pixelSize: 9 * root.s
                        font.letterSpacing: 1 * root.s
                    }
                }
            }

            LockIdentity {
                id: identity

                host: root.host
                x: folio.x + folio.width + 24 * root.s
                y: Math.max(24 * root.s, (parent.height - identity.height - 10 * root.s - 44) / 2)
                width: parent.width - x - 24 * root.s
                avatarSize: 36 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                host: root.host
                x: folio.x + folio.width + 24 * root.s
                y: identity.y + identity.height + 10 * root.s
                width: parent.width - x - 24 * root.s
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: root.ground
            }
        }

        LockMediaSlot {
            id: media

            opacity: root.stage(0.38, 0.66, 1)

            transform: Translate {
                y: 14 * (1 - root.stage(0.38, 0.70, 1))
            }

            host: root.host
            variant: "phase"
            amount: 0.9 * root.s
            x: (parent.width - width) / 2
            y: panel.y + panel.height + Math.max(20, 26 * root.s)
        }

        Item {
            id: footer

            opacity: root.stage(0.30, 0.58, 1)
            x: 32 * root.s
            y: parent.height - height - 26 * root.s
            width: parent.width - x * 2
            height: 26 * root.s

            LockWifi {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.host ? root.host.showWifi && wifiDev !== null : false
            }

            LockBattery {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                shimmerOn: root.host ? root.host.batteryShimmerOn : false
                visible: root.host ? root.host.showBattery && present : false
            }
        }
    }
}