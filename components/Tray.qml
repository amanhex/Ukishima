pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../Singletons"

/**
 * System tray. Draws StatusNotifier items as warm-tinted icons. Left-click
 * activates (preferring the resolved desktop entry), middle-click does the
 * secondary action, right-click opens the item's native menu in a floating
 * washi card, wheel scrolls the item. The menu gets its own overlay window so
 * it can grab keyboard focus for dismissal.
 */
Item {
    id: tray

    property real s: 1
    property var barWindow

    /**
     * StatusNotifier items shown in the tray. nm-applet and blueman are hidden:
     * the pill draws its own wifi and bluetooth module icons with dedicated
     * surfaces, so their tray icons would only duplicate the same status.
     * Matching runs across id, title and tooltip so applet renames stay covered.
     */
    readonly property var trayItems: SystemTray.items.values.filter(function (it) {
        if (!it)
            return false;
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase();
        return !/(nm[ _-]?applet|blueman|network[- ]?manager|bluetooth[- ]?manager)/.test(key);
    })

    visible: tray.trayItems.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 24 * tray.s

    function showMenu(item, anchorItem) {
        if (!item || !item.hasMenu)
            return;
        card.expandedIdx = -1;
        opener.menu = item.menu;
        var p = anchorItem.mapToItem(null, anchorItem.width / 2, 0);
        menu.anchorX = p.x;
        menu.open = true;
    }

    QsMenuOpener {
        id: opener
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2 * tray.s

        Repeater {
            model: tray.trayItems

            delegate: Item {
                id: slot

                required property var modelData
                readonly property var d: modelData || ({})

                Layout.preferredWidth: 24 * tray.s
                Layout.preferredHeight: 24 * tray.s

                Rectangle {
                    anchors.fill: parent
                    radius: 6 * tray.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: Theme.frameBorder
                    opacity: area.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Image {
                    anchors.centerIn: parent
                    source: slot.d.icon
                    sourceSize.width: 32
                    sourceSize.height: 32
                    width: 16 * tray.s
                    height: 16 * tray.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true
                    asynchronous: true
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (!slot.modelData)
                            return;
                        if (mouse.button === Qt.MiddleButton) {
                            slot.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            tray.showMenu(slot.modelData, slot);
                        } else if (slot.modelData.onlyMenu) {
                            tray.showMenu(slot.modelData, slot);
                        } else {
                            slot.modelData.activate();
                        }
                    }
                    onWheel: (wheel) => {
                        if (slot.modelData)
                            slot.modelData.scroll(wheel.angleDelta.y, false);
                    }
                }

                Tooltip {
                    s: tray.s
                    placement: "below"
                    title: slot.d.tooltipTitle || slot.d.title || slot.d.id
                    show: area.containsMouse && !menu.open
                }
            }
        }
    }

    /**
     * One menu line: separator, or a row with optional checkbox/radio state,
     * icon, label and a submenu chevron that rotates when expanded. Used for
     * both top-level entries and indented submenu children.
     */
    component MenuRow: Item {
        id: mrow

        property var entryData
        /** A menu model can briefly hand the delegate a null entry while the
         *  opener is being torn down; bind through a safe object so the
         *  transient null never reaches a property read. */
        readonly property var d: entryData || ({})
        property real indent: 0
        property bool expanded: false
        signal activated()

        height: d.isSeparator ? 9 * tray.s : 32 * tray.s

        Rectangle {
            visible: mrow.d.isSeparator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8 * tray.s + mrow.indent
            anchors.rightMargin: 8 * tray.s
            height: 1
            color: Theme.hair
        }

        Rectangle {
            visible: !mrow.d.isSeparator
            anchors.fill: parent
            anchors.leftMargin: mrow.indent
            radius: 8 * tray.s
            color: mrowArea.containsMouse && mrow.d.enabled
                ? Theme.frameBg : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6 * tray.s
                width: 2 * tray.s
                height: parent.height * 0.46
                radius: width / 2
                color: Theme.vermLit
                opacity: mrowArea.containsMouse && mrow.d.enabled ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            Rectangle {
                id: stateBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16 * tray.s
                readonly property bool isCheck: mrow.d.buttonType === QsMenuButtonType.CheckBox
                readonly property bool isRadio: mrow.d.buttonType === QsMenuButtonType.RadioButton
                readonly property bool present: isCheck || isRadio
                readonly property bool checked: mrow.d.checkState === Qt.Checked
                visible: present
                width: present ? 11 * tray.s : 0
                height: 11 * tray.s
                radius: isRadio ? width / 2 : 3 * tray.s
                color: "transparent"
                border.width: 1
                border.color: checked ? Theme.vermLit : Theme.border

                Rectangle {
                    anchors.centerIn: parent
                    visible: stateBox.checked
                    width: 5 * tray.s
                    height: 5 * tray.s
                    radius: stateBox.isRadio ? width / 2 : 1.5 * tray.s
                    color: Theme.vermLit
                }
            }

            Image {
                id: entryIcon
                anchors.left: stateBox.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: stateBox.present ? 8 * tray.s : 0
                width: mrow.d.icon ? 15 * tray.s : 0
                height: 15 * tray.s
                source: mrow.d.icon
                sourceSize.width: 30
                sourceSize.height: 30
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: true
                visible: mrow.d.icon
            }

            Text {
                anchors.left: entryIcon.right
                anchors.leftMargin: mrow.d.icon ? 9 * tray.s : 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.rightMargin: 14 * tray.s
                text: mrow.d.text
                color: !mrow.d.enabled ? Theme.dim
                    : (mrowArea.containsMouse ? Theme.cream : Theme.creamMenu)
                font.family: Theme.font
                font.pixelSize: 13 * tray.s
                font.weight: mrowArea.containsMouse ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            GlyphIcon {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10 * tray.s
                anchors.verticalCenter: parent.verticalCenter
                visible: mrow.d.hasChildren === true
                width: 10 * tray.s
                height: 10 * tray.s
                name: "chevron-right"
                color: mrow.expanded ? Theme.vermLit : Theme.iconDim
                stroke: 2
                rotation: mrow.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: mrowArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: mrow.d.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: mrow.activated()
            }
        }
    }

    PanelWindow {
        id: menu

        property bool open: false
        property real anchorX: 0

        onOpenChanged: {
            if (!open) {
                card.expandedIdx = -1;
                opener.menu = null;
            }
        }

        screen: tray.barWindow ? tray.barWindow.screen : null
        visible: open
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "ukishima-tray"

        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.open = false
        }

        FocusScope {
            anchors.fill: parent
            focus: menu.open

            Keys.onEscapePressed: menu.open = false

            Rectangle {
                id: card

                x: Math.max(8 * tray.s, Math.min(menu.anchorX - width / 2, menu.width - width - 8 * tray.s))
                y: 50 * tray.s
                width: 220 * tray.s
                radius: 12 * tray.s
                clip: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.cardTop }
                    GradientStop { position: 1.0; color: Theme.cardBot }
                }
                border.width: 1
                border.color: Theme.border

                property int expandedIdx: -1

                implicitHeight: col.implicitHeight + 12 * tray.s
                height: implicitHeight

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 10 * tray.s
                    anchors.rightMargin: 10 * tray.s
                    height: 1
                    color: Theme.sheen
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadow
                    shadowBlur: 0.9
                    shadowVerticalOffset: 4 * tray.s
                }

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * tray.s
                    spacing: 0

                    Repeater {
                        model: opener.children ? opener.children.values : []

                        delegate: Column {
                            id: entry

                            required property var modelData
                            required property int index
                            readonly property bool expanded: card.expandedIdx === index

                            width: col.width

                            MenuRow {
                                width: parent.width
                                entryData: entry.modelData
                                expanded: entry.expanded
                                onActivated: {
                                    if (!entry.modelData)
                                        return;
                                    if (entry.modelData.hasChildren) {
                                        card.expandedIdx = entry.expanded ? -1 : entry.index;
                                    } else {
                                        entry.modelData.triggered();
                                        menu.open = false;
                                    }
                                }
                            }

                            QsMenuOpener {
                                id: childOpener
                                menu: entry.expanded ? entry.modelData : null
                            }

                            Repeater {
                                model: childOpener.children ? childOpener.children.values : []

                                delegate: MenuRow {
                                    required property var modelData
                                    width: entry.width
                                    indent: 14 * tray.s
                                    entryData: modelData
                                    onActivated: {
                                        if (!modelData)
                                            return;
                                        if (!modelData.hasChildren) {
                                            modelData.triggered();
                                            menu.open = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
