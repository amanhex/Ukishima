import QtQuick
import ".."

/**
 * Reactive — a technical readout: a faint registration grid in the top-left,
 * corner ticks, a split clock with a red colon, and the glyph bay on the right.
 * Adapted from Chaldea's reactive relay-tiles study.
 */
Item {
    id: root

    property var host: null

    readonly property real s: Math.max(0.55, Math.min(1.35, Math.min(width / 1920, height / 1200)))
    readonly property bool narrow: width < 980 * root.s
    readonly property color ink: "#e4e2dc"
    readonly property color muted: "#93918b"
    readonly property color accent: "#d1161c"
    readonly property color line: "#343330"

    readonly property string hours: {
        const d = clockState.now;
        return root.host && root.host.use12h ? Qt.formatTime(d, "h") : Qt.formatTime(d, "HH");
    }
    readonly property string minutes: Qt.formatTime(clockState.now, "mm")
    readonly property string suffix: root.host && root.host.use12h ? Qt.formatTime(clockState.now, "AP") : ""
    readonly property string dateLine: clockState.now.toLocaleDateString(Qt.locale(), "ddd // d MMMM yyyy").toUpperCase()

    QtObject {
        id: clockState

        property var now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockState.now = new Date()
    }

    Item {
        id: furniture

        anchors.fill: parent
        opacity: root.host ? root.host.stage(40 / 380, 320 / 380, 1) * root.host.held : 0

        Canvas {
            anchors.fill: parent
            opacity: 0.12
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const fade = ctx.createLinearGradient(0, 0, width * 0.42, 0);
                fade.addColorStop(0, "#ad1a20");
                fade.addColorStop(1, "transparent");
                ctx.strokeStyle = fade;
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (let x = 0.5; x <= width * 0.42; x += 24) {
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                }
                for (let y = 0.5; y < height; y += 24) {
                    ctx.moveTo(0, y);
                    ctx.lineTo(width * 0.42, y);
                }
                ctx.stroke();
            }
        }

        Item {
            x: 13 * root.s
            y: 13 * root.s
            width: 20 * root.s
            height: 20 * root.s

            Rectangle { width: 20 * root.s; height: 1 * root.s; color: root.accent }
            Rectangle { width: 1 * root.s; height: 20 * root.s; color: root.accent }
        }

        Item {
            x: parent.width - 33 * root.s
            y: parent.height - 33 * root.s
            width: 20 * root.s
            height: 20 * root.s

            Rectangle { y: 19 * root.s; width: 20 * root.s; height: 1 * root.s; color: root.accent }
            Rectangle { x: 19 * root.s; width: 1 * root.s; height: 20 * root.s; color: root.accent }
        }

        Item {
            id: header

            x: 33 * root.s
            y: 27 * root.s
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
                    text: "REACTIVE"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 11 * root.s
                    font.letterSpacing: 1.2 * root.s
                }
            }
        }

        Item {
            id: clockCol

            x: root.narrow ? (parent.width - width) / 2 : 33 * root.s
            y: root.narrow ? header.y + header.height + 50 * root.s : Math.max(header.y + header.height + 70 * root.s, parent.height * 0.23)
            width: root.narrow ? Math.min(parent.width - 66 * root.s, 380 * root.s) : Math.min(380 * root.s, parent.width * 0.34)
            height: identity.y + identity.height + 10 * root.s + 44

            Row {
                spacing: 9 * root.s

                Rectangle {
                    width: 6 * root.s
                    height: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                }

                Text {
                    text: "SESSION LOCKED"
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1.7 * root.s
                }
            }

            Row {
                id: timeRow

                y: 24 * root.s
                height: 104 * root.s

                Text {
                    text: root.hours
                    color: root.ink
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: (root.narrow ? 66 : 84) * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: -4 * root.s
                }

                Text {
                    text: ":"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: (root.narrow ? 66 : 84) * root.s
                    font.letterSpacing: -4 * root.s
                }

                Text {
                    text: root.minutes
                    color: root.ink
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: (root.narrow ? 66 : 84) * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: -4 * root.s
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16 * root.s
                    text: root.suffix
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 12 * root.s
                }
            }

            Row {
                y: 140 * root.s
                spacing: 8 * root.s

                Text {
                    text: root.dateLine.split(" // ")[0]
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 0.4 * root.s
                }

                Text {
                    text: "//"
                    color: root.accent
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10 * root.s
                }

                Text {
                    text: root.dateLine.split(" // ")[1] || ""
                    color: root.muted
                    font.family: "JetBrainsMono NF"
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 0.4 * root.s
                }
            }

            LockIdentity {
                id: identity

                host: root.host
                y: 164 * root.s
                width: parent.width
                avatarSize: 38 * root.s
                horizontal: true
                ink: root.ink
                muted: root.muted
            }

            LockField {
                y: identity.y + identity.height + 10 * root.s
                width: parent.width
                host: root.host
                ink: root.ink
                muted: root.muted
                accent: root.accent
                line: root.line
                ground: "#090909"
            }
        }

        Item {
            id: bay

            visible: !root.narrow
            x: parent.width - width - 33 * root.s
            y: Math.max(header.y + header.height + 46 * root.s, parent.height * 0.22)
            width: Math.min(300 * root.s, parent.width * 0.20)
            height: width + 90 * root.s

            Rectangle {
                x: -26 * root.s
                width: 1 * root.s
                height: parent.height
                color: root.line
            }

            Text {
                text: "鍵"
                color: root.ink
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 26 * root.s
                font.letterSpacing: 7 * root.s
            }

            Text {
                anchors.right: parent.right
                y: 2 * root.s
                text: "一七式衛人"
                color: root.muted
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 11 * root.s
                font.letterSpacing: 2 * root.s
            }

            Rectangle {
                y: 52 * root.s
                width: parent.width
                height: width
                color: "#090909"
            }

            LockGlyph {
                host: root.host
                y: 52 * root.s
                width: parent.width
                height: parent.width
                showGround: false
                phase: root.host ? root.host.context.currentText.length : 0
            }

            Row {
                y: parent.width + 66 * root.s
                width: parent.width
                spacing: 10 * root.s

                Repeater {
                    model: 4

                    Item {
                        required property int index
                        width: (parent.width - 30 * root.s) / 4
                        height: 27 * root.s

                        Rectangle {
                            width: parent.width
                            height: 1 * root.s
                            color: index === 3 ? root.accent : root.line
                        }

                        Text {
                            y: 10 * root.s
                            text: "0" + (index + 1) + (index === 3 ? " ◆" : "")
                            color: index === 3 ? root.accent : root.muted
                            font.family: "JetBrainsMono NF"
                            font.pixelSize: 9 * root.s
                        }
                    }
                }
            }
        }

        LockMediaSlot {
            id: media

            host: root.host
            variant: "reactive"
            amount: 0.86 * root.s
            x: root.narrow ? (parent.width - width) / 2 : 33 * root.s
            y: clockCol.y + clockCol.height + Math.max(20, 26 * root.s)
        }

        Item {
            id: footer

            x: 33 * root.s
            y: parent.height - height - 25 * root.s
            width: parent.width - x * 2
            height: 26 * root.s

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "07:04 // 704"
                color: root.muted
                font.family: "JetBrainsMono NF"
                font.pixelSize: 9 * root.s
                font.letterSpacing: 1.2 * root.s
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