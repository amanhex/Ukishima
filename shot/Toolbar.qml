import QtQuick

/**
 * Annotate-stage action bar: tool, undo, ink swatches, widths, save/cancel,
 * and the status line. Text labels, not glyphs — this config shares no
 * components with the main shell by design.
 */
Item {
    id: bar

    required property var shell
    readonly property var tools: [{
        "key": "pen",
        "label": "Pen"
    }, {
        "key": "rect",
        "label": "Rect"
    }, {
        "key": "arrow",
        "label": "Arrow"
    }, {
        "key": "text",
        "label": "Text"
    }]
    readonly property var inks: ["#f2ede4", "#e0563b", "#e8b93e", "#7fb069", "#5b8dd9", "#1a1815"]
    readonly property var widths: [2, 4, 8]

    width: row.width + 28
    height: row.height + (shell.status ? statusText.height + 18 : 14)

    Rectangle {
        anchors.fill: parent
        radius: 13
        color: "#f2161310"
        border.width: 1
        border.color: shell.border
    }

    Column {
        id: row

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 7
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Repeater {
                model: bar.tools

                Rectangle {
                    required property var modelData

                    width: 52
                    height: 30
                    radius: 8
                    color: shell.tool === modelData.key ? "#33e0563b" : "transparent"
                    border.width: 1
                    border.color: shell.tool === modelData.key ? shell.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: shell.tool === modelData.key ? shell.cream : shell.subtle
                        font.family: shell.font
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.tool = modelData.key
                    }

                }

            }

            Rectangle {
                width: 1
                height: 30
                color: shell.border
            }

            Rectangle {
                width: 52
                height: 30
                radius: 8
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "Undo"
                    color: undoArea.containsMouse ? shell.cream : shell.subtle
                    font.family: shell.font
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: undoArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: shell.undo()
                }

            }

            Rectangle {
                width: 1
                height: 30
                color: shell.border
            }

            Repeater {
                model: bar.inks

                Rectangle {
                    required property var modelData

                    width: 24
                    height: 30
                    radius: 8
                    color: "transparent"
                    border.width: shell.ink === modelData ? 2 : 0
                    border.color: shell.cream

                    Rectangle {
                        anchors.centerIn: parent
                        width: 15
                        height: 15
                        radius: 7
                        color: modelData
                        border.width: 1
                        border.color: shell.border
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.ink = modelData
                    }

                }

            }

            Rectangle {
                width: 1
                height: 30
                color: shell.border
            }

            Repeater {
                model: bar.widths

                Rectangle {
                    required property var modelData

                    width: 30
                    height: 30
                    radius: 8
                    color: shell.inkW === modelData ? "#33e0563b" : "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 18
                        height: modelData > 6 ? 6 : modelData
                        radius: 3
                        color: shell.cream
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.inkW = modelData
                    }

                }

            }

            Rectangle {
                width: 1
                height: 30
                color: shell.border
            }

            Rectangle {
                width: 56
                height: 30
                radius: 8
                color: saveArea.containsMouse ? shell.accent : "#33e0563b"

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: shell.cream
                    font.family: shell.font
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: saveArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: shell.doSave()
                }

            }

            Rectangle {
                width: 30
                height: 30
                radius: 8
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: cancelArea.containsMouse ? shell.cream : shell.subtle
                    font.family: shell.font
                    font.pixelSize: 12
                }

                MouseArea {
                    id: cancelArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: shell.backToSelect()
                }

            }

        }

    }

    Text {
        id: statusText

        anchors.top: row.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        visible: shell.status
        text: shell.status
        color: shell.accent
        font.family: shell.font
        font.pixelSize: 11
    }

}
