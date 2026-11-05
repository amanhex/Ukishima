import QtQuick
import ".."

/**
 * Editorial — a centred poster composition: clock and login on the left, the
 * compound glyph in the middle, the live media card on the right. Adapted from
 * Chaldea's editorial studies.
 */
Item {
    id: root

    property var host: null

    function stage(from, to, peak) {
        return root.host ? root.host.stage(from, to, peak) : 0;
    }

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 1050 * root.s
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
            x: 40 * root.s
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
                    font.letterSpacing: 1.4 * root.s
                }

                Text {
                    text: "//"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                }

                Text {
                    text: "EDITORIAL"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.4 * root.s
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
                    text: "◆ 17"
                    color: "#090909"
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 13 * root.s
                    font.letterSpacing: 2 * root.s
                }
            }
        }

        Item {
            id: composition

            x: (parent.width - width) / 2
            y: root.narrow ? header.y + header.height + 42 * root.s : Math.max(header.y + header.height + 54 * root.s, parent.height * 0.20)
            width: root.narrow ? Math.min(parent.width - 56 * root.s, 420 * root.s) : Math.min(1040 * root.s, parent.width - 96 * root.s)
            height: root.narrow
                ? mediaNarrow.y + mediaNarrow.height
                : Math.min(420 * root.s, parent.height * 0.56)

            LockClock {
                id: clock

                opacity: root.stage(0.15, 0.47, 1)

                transform: Translate {
                    y: -22 * (1 - root.stage(0.15, 0.52, 1))
                }

                host: root.host
                width: root.narrow ? parent.width : 330 * root.s
                timeSize: (root.narrow ? 56 : 74) * root.s
                dateSize: 10 * root.s
                alignLeft: !root.narrow
                ink: root.ink
                muted: root.muted
            }

            LockIdentity {
                id: identity

                opacity: root.stage(0.24, 0.56, 1)

                transform: Translate {
                    y: 20 * (1 - root.stage(0.24, 0.60, 1))
                }

                host: root.host
                visible: !root.narrow
                y: clock.y + clock.height + 22 * root.s
                width: 230 * root.s
                avatarSize: 40 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                id: field

                opacity: root.stage(0.30, 0.62, 1)

                transform: Translate {
                    y: 20 * (1 - root.stage(0.30, 0.66, 1))
                }

                host: root.host
                visible: !root.narrow
                y: identity.y + identity.height + 12 * root.s
                width: 330 * root.s
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: "#090909"
            }

            LockIdentity {
                id: identityNarrow

                opacity: root.stage(0.24, 0.56, 1)

                transform: Translate {
                    y: 20 * (1 - root.stage(0.24, 0.60, 1))
                }

                host: root.host
                visible: root.narrow
                y: clock.y + clock.height + 16 * root.s
                width: parent.width
                avatarSize: 40 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                id: fieldNarrow

                opacity: root.stage(0.30, 0.62, 1)

                transform: Translate {
                    y: 20 * (1 - root.stage(0.30, 0.66, 1))
                }

                host: root.host
                visible: root.narrow
                y: identityNarrow.y + identityNarrow.height + 10 * root.s
                width: parent.width
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: "#090909"
            }

            Item {
                id: glyphCol

                opacity: root.stage(0.12, 0.44, 1)

                transform: Translate {
                    y: -16 * (1 - root.stage(0.12, 0.48, 1))
                }

                visible: !root.narrow
                //* Sit clear of both the login column and the media column
                //* instead of dead-centre: at 1920x1200 the red spine used to
                //* land ~3px from the input field. Field gap is 44*s; the
                //* spine takes 22*s of that, leaving 22*s of real space.
                x: field.x + field.width + 44 * root.s
                y: 0
                width: Math.max(80 * root.s, Math.min(330 * root.s, parent.height * 0.82, playerCol.x - x - 40 * root.s))
                height: parent.height

                Rectangle {
                    x: -22 * root.s
                    width: 2 * root.s
                    height: parent.height
                    color: root.accent
                    opacity: 0.7
                }

                LockGlyph {
                    host: root.host
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.width
                    phase: root.host ? root.host.context.currentText.length : 0
                }
            }

            Column {
                id: playerCol

                opacity: root.stage(0.38, 0.66, 1)

                transform: Translate {
                    y: 14 * (1 - root.stage(0.38, 0.70, 1))
                }

                visible: !root.narrow
                anchors.right: parent.right
                y: field.y + field.height + Math.max(20, 26 * root.s)
                spacing: 14 * root.s

                Text {
                    text: "NOW PLAYING"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 2 * root.s
                }

                LockMediaSlot {
                    host: root.host
                    variant: "editorial"
                    amount: 0.86 * root.s
                }

                Text {
                    text: "RELAY // 704"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 1.6 * root.s
                }
            }

            LockMediaSlot {
                id: mediaNarrow

                opacity: root.stage(0.38, 0.66, 1)

                transform: Translate {
                    y: 14 * (1 - root.stage(0.38, 0.70, 1))
                }

                host: root.host
                variant: "editorial"
                visible: root.narrow
                amount: 0.82 * root.s
                x: (parent.width - width) / 2
                y: fieldNarrow.y + fieldNarrow.height + Math.max(20, 26 * root.s)
            }
        }

        Item {
            id: footer

            opacity: root.stage(0.30, 0.58, 1)
            x: 40 * root.s
            y: parent.height - height - 26 * root.s
            width: parent.width - x * 2
            height: 30 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * root.s

                Rectangle {
                    width: 92 * root.s
                    height: 25 * root.s
                    color: root.accent

                    Text {
                        anchors.centerIn: parent
                        text: "UKISHIMA"
                        color: "#090909"
                        font.family: "JetBrainsMono NF"
                        font.pixelSize: 10 * root.s
                        font.letterSpacing: 1.6 * root.s
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "播種船 ウキシマ"
                    color: root.muted
                    font.family: "Noto Sans CJK JP"
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1 * root.s
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * root.s

                Item {
                    width: 20 * root.s
                    height: 30 * root.s

                    LockWifi {
                        anchors.centerIn: parent
                        visible: root.host ? root.host.showWifi && wifiDev !== null : false
                    }
                }

                Item {
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
}