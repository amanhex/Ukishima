pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * 音 SOUND surface, opened from the music glyph in the Mixer header. Three tabs
 * over the panels: EQ (modes, spectrum, ten bands, shelves, AutoEQ, night),
 * Apps (per-app volume, mute, output routing) and Mic (input gain). All the
 * state lives in the `Sound` singleton; this is the chrome and the tab switch.
 */
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 14

    property string tab: "eq"
    /** True on the Mic tab: the shared device row shows the input instead of the output. */
    readonly property bool micTab: root.tab === "mic"
    /** True while the output/input device dropdown is showing. */
    property bool pickerOpen: false

    implicitHeight: content.implicitHeight

    ameForm: root.tab === "eq" ? eqPanel.ameForm : "off"
    amePoint: root.tab === "eq"
        ? eqPanel.mapToItem(root, eqPanel.amePoint.x, eqPanel.amePoint.y)
        : Qt.point(width / 2, height / 2)

    onActiveChanged: if (!active)
        root.closePopovers()

    /** Close the EQ popovers, the app routing menu and the device dropdown; on tab change and on close. */
    function closePopovers() {
        eqPanel.closePopovers();
        appsPanel.routeStream = null;
        root.pickerOpen = false;
    }

    Column {
        id: content
        width: parent.width
        spacing: 0

        Item {
            id: headRow
            width: parent.width
            height: 24 * root.s
            /** Above the device row and body so header tooltips (undo) are not clipped behind them. */
            z: 1

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "音"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Theme.fontJpWeight
                    font.pixelSize: 16 * root.s
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SOUND"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            SettingsSeg {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                options: [
                    { label: "EQ", value: "eq" },
                    { label: "Apps", value: "apps" },
                    { label: "Mic", value: "mic" }
                ]
                value: root.tab
                onPicked: (v) => { root.tab = v; root.closePopovers(); }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.s

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.tab === "eq"
                    spacing: 7 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "EQ"
                        color: Sound.eq ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                    }

                    LinkToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        on: Sound.eq
                        onToggled: Sound.setEq(!Sound.eq)
                    }
                }

                Item {
                    id: undoItem
                    anchors.verticalCenter: parent.verticalCenter
                    /** Always in the header; dimmed and inert until there is a step to undo, so it never flickers in and out. */
                    readonly property bool hasUndo: Sound.undoStack.length > 0
                    opacity: undoItem.hasUndo ? 1 : 0.35
                    width: 15 * root.s
                    height: 15 * root.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "undo"
                        color: undoArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.8
                    }

                    MouseArea {
                        id: undoArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        enabled: undoItem.hasUndo
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Sound.undo()
                    }

                    Tooltip {
                        s: root.s
                        placement: "below"
                        title: "Undo " + Sound.undoLabel.toLowerCase()
                        show: undoArea.containsMouse && undoItem.hasUndo
                    }
                }
            }
        }

        Item { width: 1; height: 9 * root.s }
        Rectangle { width: parent.width; height: 1; color: Theme.hair }
        Item { width: 1; height: 10 * root.s }

        /** Output on the EQ/Apps tabs, input on Mic: the one place a device is chosen. */
        Item {
            id: deviceRow
            width: parent.width
            height: 26 * root.s

            Text {
                id: deviceCap
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.micTab ? "Input" : "Output"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }

            Rectangle {
                id: deviceField
                anchors.left: deviceCap.right
                anchors.leftMargin: 10 * root.s
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 26 * root.s
                radius: 8 * root.s
                color: root.pickerOpen ? Qt.alpha(Theme.onGlow, 0.14) : (fieldHover.hovered ? Theme.frameBg : "transparent")
                border.width: 1
                border.color: root.pickerOpen ? Qt.alpha(Theme.onGlow, 0.5) : Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                HoverHandler { id: fieldHover }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * root.s
                    anchors.right: chevron.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: devMenu.label(root.micTab ? Sound.source : Sound.sink) || (root.micTab ? "No input" : "No output")
                    elide: Text.ElideRight
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }

                GlyphIcon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: 9 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s
                    height: 12 * root.s
                    name: root.pickerOpen ? "chevron-up" : "chevron-down"
                    color: Theme.iconDim
                    stroke: 2
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickerOpen = !root.pickerOpen
                }
            }
        }

        Item { width: 1; height: 12 * root.s }

        /** Tab body: only the visible panel's height drives the surface, so the pill morphs per tab. */
        Item {
            id: body
            width: parent.width
            implicitHeight: root.tab === "eq" ? eqPanel.implicitHeight
                          : root.tab === "apps" ? appsPanel.implicitHeight
                          : micPanel.implicitHeight

            EqPanel {
                id: eqPanel
                width: parent.width
                height: implicitHeight
                visible: root.tab === "eq"
                s: root.s
                live: root.open && root.tab === "eq"
            }

            AppsPanel {
                id: appsPanel
                width: parent.width
                height: implicitHeight
                visible: root.tab === "apps"
                s: root.s
                live: root.open && root.tab === "apps"
            }

            MicPanel {
                id: micPanel
                width: parent.width
                height: implicitHeight
                visible: root.tab === "mic"
                s: root.s
            }
        }
    }

    /** Device dropdown, floated below the device row so the surface height stays put while it is open. */
    DeviceMenu {
        id: devMenu
        s: root.s
        open: root.pickerOpen
        anchors.top: parent.top
        anchors.topMargin: deviceRow.y + deviceRow.height + 4 * root.s
        anchors.right: parent.right
        width: deviceField.width
        model: root.micTab ? Sound.inputSources : Sound.outputSinks
        current: root.micTab ? Sound.source : Sound.sink
        onPick: (node) => {
            if (root.micTab)
                Pipewire.preferredDefaultAudioSource = node;
            else
                Pipewire.preferredDefaultAudioSink = node;
            root.pickerOpen = false;
        }
    }
}
