pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import "../components"

/**
 * 天 WEATHER surface: a live read-out of the Open-Meteo forecast already served
 * by the Weather singleton, so no extra dependency or network hops are added
 * here. Current conditions lead (hero glyph, temperature, humidity), then a
 * 24-hour hourly strip of the next few hours and a five-day daily forecast
 * beneath a hairline. Everything is driven straight off `Weather.hourly` and
 * `Weather.daily`; a not-yet-ready read shows only the header and a dim hint.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitWidth: Math.max(header.implicitWidth, 252 * s)
    implicitHeight: content.implicitHeight

    ameForm: "off"

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            id: header
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "天"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WEATHER"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.city.length ? Weather.city : "Local"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8 * root.s
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Column {
            width: parent.width
            topPadding: 15 * root.s
            spacing: 13 * root.s
            visible: Weather.ready

            Row {
                width: parent.width
                spacing: 14 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.tempNow + "°"
                    color: Weather.codeNow >= 95 ? Theme.vermLit : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 42 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: -1 * root.s
                    font.features: { "tnum": 1 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4 * root.s

                    Row {
                        spacing: 7 * root.s
                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22 * root.s
                            height: 22 * root.s
                            name: Weather.glyphFor(Weather.codeNow, Weather.isDay)
                            color: Theme.flameGlow
                            stroke: 1.7
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.labelFor(Weather.codeNow)
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                            font.weight: Font.DemiBold
                        }
                    }

                    Row {
                        spacing: 5 * root.s
                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11 * root.s
                            height: 11 * root.s
                            name: "droplet"
                            color: Theme.subtle
                            stroke: 1.6
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.humidity + "%"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            Column {
                width: parent.width
                spacing: 8 * root.s

                Text {
                    text: "NEXT 24H"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                }

                Row {
                    width: parent.width
                    spacing: 8 * root.s
                    Repeater {
                        model: Weather.hourly.slice(0, 8)
                        Item {
                            width: (parent.width - parent.spacing * 7) / 8
                            height: 52 * root.s
                            Column {
                                anchors.centerIn: parent
                                spacing: 4 * root.s
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.hour + "h"
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 8.5 * root.s
                                    font.weight: Font.Medium
                                    font.features: { "tnum": 1 }
                                }
                                GlyphIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    name: Weather.glyphFor(modelData.code, true)
                                    color: Theme.iconDim
                                    stroke: 1.6
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.temp + "°"
                                    color: Theme.cream
                                    font.family: Theme.font
                                    font.pixelSize: 10.5 * root.s
                                    font.weight: Font.DemiBold
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            Column {
                width: parent.width
                spacing: 6 * root.s

                Text {
                    text: "5 DAY"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                }

                Repeater {
                    model: Weather.daily
                    Row {
                        width: parent.width
                        height: 26 * root.s
                        spacing: 8 * root.s

                        Text {
                            width: 40 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.day
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.Medium
                            font.capitalization: Font.AllUppercase
                        }
                        GlyphIcon {
                            width: 15 * root.s
                            height: 15 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            name: Weather.glyphFor(modelData.code, true)
                            color: Theme.iconDim
                            stroke: 1.6
                        }
                        Text {
                            width: 52 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.labelFor(modelData.code)
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
                        }
                        Item {
                            width: parent.width - 40 * root.s - 15 * root.s - 52 * root.s - 44 * root.s - 16 * root.s
                            height: parent.height
                        }
                        Text {
                            width: 44 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData.rh + "%"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            width: 40 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData.temp + "°"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 11.5 * root.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            topPadding: 15 * root.s
            spacing: 5 * root.s
            visible: !Weather.ready

            Text {
                width: parent.width
                text: Weather.city.length ? Weather.city : "Weather"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "Waiting for forecast…"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
            }
        }
    }
}
