import QtQuick
import ".."

/**
 * Spine — a print-index arrangement: clock on the left, vertical title on the
 * right edge, the glyph bay between them and the login under the bay. Adapted
 * from Chaldea's index-spine study.
 */
Item {
    id: root

    property var host: null

    function stage(from, to, peak) {
        return root.host ? root.host.stage(from, to, peak) : 0;
    }

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 980 * root.s
    readonly property color ink: "#e4e2dc"
    readonly property color muted: "#98948a"
    readonly property color accent: "#d1161c"
    readonly property color line: "#393630"

    Item {
        id: furniture

        anchors.fill: parent
        opacity: root.host ? root.host.held : 0

        Item {
            id: header

            opacity: root.stage(0, 0.30, 1)
            x: 32 * root.s
            y: 26 * root.s
            width: parent.width - x * 2
            height: 28 * root.s

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
                    text: "INDEX SPINE"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
            }
        }

        LockClock {
            id: clock

            opacity: root.stage(0.15, 0.47, 1)

            transform: Translate {
                y: -22 * (1 - root.stage(0.15, 0.52, 1))
            }

            host: root.host
            x: root.narrow ? (parent.width - width) / 2 : 64 * root.s
            y: root.narrow ? header.y + header.height + 46 * root.s : Math.max(header.y + header.height + 70 * root.s, parent.height * 0.23)
            width: root.narrow ? Math.min(parent.width - 64 * root.s, 340 * root.s) : 220 * root.s
            timeSize: (root.narrow ? 58 : 92) * root.s
            dateSize: 10 * root.s
            alignLeft: !root.narrow
            ink: root.ink
            muted: root.muted
        }

        Item {
            id: bay

            opacity: root.stage(0.12, 0.44, 1)

            transform: Translate {
                y: -16 * (1 - root.stage(0.12, 0.48, 1))
            }

            x: root.narrow ? (parent.width - width) / 2 : (parent.width - width) / 2 - 40 * root.s
            y: root.narrow ? clock.y + clock.height + 24 * root.s : Math.max(header.y + header.height + 48 * root.s, parent.height * 0.20)
            width: root.narrow ? Math.min(parent.width - 100 * root.s, 300 * root.s) : Math.min(350 * root.s, parent.height * 0.40)
            height: width + 44 * root.s

            LockGlyph {
                host: root.host
                width: parent.width
                height: parent.width
                phase: root.host ? root.host.context.currentText.length : 0
            }

            Rectangle {
                y: parent.width + 18 * root.s
                width: parent.width
                height: 1
                color: root.line
            }

            Text {
                y: parent.width + 28 * root.s
                text: "TYPE-17"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1 * root.s
            }

            Text {
                anchors.right: parent.right
                y: parent.width + 28 * root.s
                text: "// 704"
                color: root.accent
                font.family: "JetBrainsMono NF"
                font.pixelSize: 10 * root.s
                font.letterSpacing: 1 * root.s
            }
        }

        Item {
            id: title

            opacity: root.stage(0.06, 0.38, 1)

            transform: Translate {
                y: -14 * (1 - root.stage(0.06, 0.42, 1))
            }

            visible: !root.narrow
            x: parent.width - width - 48 * root.s
            y: Math.max(header.y + header.height + 54 * root.s, parent.height * 0.22)
            width: 64 * root.s
            height: 330 * root.s

            Rectangle {
                width: parent.width
                height: 3 * root.s
                color: root.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 23 * root.s
                text: "鍵\n衛"
                color: root.ink
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 52 * root.s
                lineHeightMode: Text.FixedHeight
                lineHeight: 60 * root.s
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 160 * root.s
                text: "東\n亜\n重\n工"
                color: root.muted
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 11 * root.s
                lineHeightMode: Text.FixedHeight
                lineHeight: 16 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Item {
            id: entry

            opacity: root.stage(0.24, 0.56, 1)

            transform: Translate {
                y: 24 * (1 - root.stage(0.24, 0.60, 1))
            }

            x: bay.x
            y: bay.y + bay.height + 24 * root.s
            width: bay.width
            height: identity.height + 12 * root.s + 44

            LockIdentity {
                id: identity

                host: root.host
                width: parent.width
                avatarSize: 38 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                y: identity.height + 12 * root.s
                width: parent.width
                host: root.host
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: "#090909"
            }
        }

        LockMediaSlot {
            id: media

            opacity: root.stage(0.38, 0.66, 1)

            transform: Translate {
                y: 14 * (1 - root.stage(0.38, 0.70, 1))
            }

            host: root.host
            variant: "spine"
            amount: 0.86 * root.s
            x: entry.x
            y: entry.y + entry.height + Math.max(20, 26 * root.s)
        }

        Item {
            id: footer

            opacity: root.stage(0.30, 0.58, 1)
            x: 32 * root.s
            y: parent.height - height - 25 * root.s
            width: parent.width - x * 2
            height: 28 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.s

                Text {
                    text: "継衛"
                    color: root.ink
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1 * root.s
                }

                Text {
                    text: "// UKISHIMA"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
            }

            LockWifi {
                anchors.right: batteryHolder.left
                anchors.rightMargin: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: root.host ? root.host.showWifi && wifiDev !== null : false
            }

            Item {
                id: batteryHolder

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 37 * root.s
                height: 30 * root.s

                LockBattery {
                    anchors.centerIn: parent
                    shimmerOn: root.host ? root.host.batteryShimmerOn : false
                    visible: root.host ? root.host.showBattery && present : false
                }
            }
        }
    }
}