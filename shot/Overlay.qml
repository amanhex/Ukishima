import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * One fullscreen overlay per output. Select phase paints the grim still and
 * takes the drag (region) or the hover-pick (window); annotate phase (only on
 * the selection's screen) paints the grim re-capture 1:1 with the strokes
 * over it and exports that composite. Hidden during the re-capture so grim
 * never photographs this UI.
 */
PanelWindow {
    id: win

    required property var shell
    required property var modelData
    readonly property var mon: shell.monFor(modelData.name) || {
        "name": modelData.name,
        "x": 0,
        "y": 0,
        "w": modelData.width,
        "h": modelData.height
    }
    readonly property bool isAnnot: shell.phase === "annotate" && shell.annotScreen === mon.name
    readonly property bool selecting: shell.phase === "select" && stillImg.status === Image.Ready
    readonly property var lsel: localSel()
    property var hoverWin: null
    property real hoverX: 0
    property real hoverY: 0

    //* Global selection intersected with this output, screen-local.
    function localSel() {
        var s = shell.sel;
        if (!s.valid)
            return null;

        var x0 = Math.max(s.x, mon.x), y0 = Math.max(s.y, mon.y);
        var x1 = Math.min(s.x + s.w, mon.x + mon.w);
        var y1 = Math.min(s.y + s.h, mon.y + mon.h);
        if (x1 <= x0 || y1 <= y0)
            return null;

        return {
            "x": x0 - mon.x,
            "y": y0 - mon.y,
            "w": x1 - x0,
            "h": y1 - y0
        };
    }

    function hitWindow(gx, gy) {
        var cs = shell.clients;
        for (var i = 0; i < cs.length; i++) {
            var c = cs[i];
            if (gx >= c.x && gx < c.x + c.w && gy >= c.y && gy < c.y + c.h)
                return c;

        }
        return null;
    }

    function commitEditor() {
        if (shell.textAt && editor.text.length)
            shell.addStroke({
            "type": "text",
            "pts": [[shell.textAt.x, shell.textAt.y]],
            "color": shell.ink,
            "w": shell.inkW,
            "size": 12 + shell.inkW * 2,
            "text": editor.text
        });

        shell.textAt = null;
        editor.text = "";
        keyGrab.forceActiveFocus();
    }

    function touchDraft() {
        shell.draft = Object.assign({
        }, shell.draft);
    }

    function pressAt(gx, gy) {
        if (shell.phase !== "annotate")
            return ;

        if (shell.textAt)
            commitEditor();

        if (shell.tool === "text") {
            shell.textAt = {
                "x": gx,
                "y": gy
            };
            editor.text = "";
            editor.forceActiveFocus();
            return ;
        }
        shell.draft = {
            "type": shell.tool,
            "pts": [[gx, gy], [gx, gy]],
            "color": shell.ink,
            "w": shell.inkW
        };
    }

    function moveTo(gx, gy) {
        var d = shell.draft;
        if (!d)
            return ;

        if (d.type === "pen")
            d.pts = d.pts.concat([[gx, gy]]);
        else
            d.pts = [d.pts[0], [gx, gy]];
        touchDraft();
    }

    function releaseAt() {
        var d = shell.draft;
        if (!d)
            return ;

        var ok = false;
        if (d.type === "pen") {
            ok = d.pts.length > 1;
        } else {
            var dx = d.pts[1][0] - d.pts[0][0], dy = d.pts[1][1] - d.pts[0][1];
            ok = Math.hypot(dx, dy) > 6;
        }
        if (ok)
            shell.addStroke(d);

        shell.draft = null;
    }

    function exportShot(path) {
        exportBox.grabToImage(function(res) {
            if (!res || !res.saveToFile(path))
                shell.onExportFailed();
            else
                shell.onExportSaved(path);
        });
    }

    screen: modelData
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "ukishima-shot"
    color: "transparent"
    visible: shell.phase === "select" || (shell.phase === "annotate" && shell.annotScreen === mon.name)

    Item {
        id: keyGrab

        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                if (shell.phase === "annotate")
                    shell.backToSelect();
                else
                    shell.doQuit();
                keyGrab.forceActiveFocus();
                e.accepted = true;
            } else if (shell.phase === "annotate" && !editor.visible) {
                if ((e.key === Qt.Key_S && (e.modifiers & Qt.ControlModifier)) || e.key === Qt.Key_Return) {
                    shell.doSave();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) {
                    shell.undo();
                    e.accepted = true;
                } else if (e.key === Qt.Key_P) {
                    shell.tool = "pen";
                    e.accepted = true;
                } else if (e.key === Qt.Key_R) {
                    shell.tool = "rect";
                    e.accepted = true;
                } else if (e.key === Qt.Key_A) {
                    shell.tool = "arrow";
                    e.accepted = true;
                } else if (e.key === Qt.Key_T) {
                    shell.tool = "text";
                    e.accepted = true;
                }
            }
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Connections {
        function onSaveRequested() {
            if (win.isAnnot)
                exportShot(shell.outPath());

        }

        target: shell
    }

    // ——— select-phase still ———
    Image {
        id: stillImg

        anchors.fill: parent
        visible: !win.isAnnot
        source: shell.stills[mon.name] ? "file://" + shell.stills[mon.name] : ""
        fillMode: Image.Stretch
        cache: false
        asynchronous: true
    }

    // Dim everything outside the selection (ryoshot scrim quartet).
    Repeater {
        model: win.lsel && shell.phase === "select" ? [{
            "x": 0,
            "y": 0,
            "w": win.width,
            "h": win.lsel.y
        }, {
            "x": 0,
            "y": win.lsel.y + win.lsel.h,
            "w": win.width,
            "h": win.height - win.lsel.y - win.lsel.h
        }, {
            "x": 0,
            "y": win.lsel.y,
            "w": win.lsel.x,
            "h": win.lsel.h
        }, {
            "x": win.lsel.x + win.lsel.w,
            "y": win.lsel.y,
            "w": win.width - win.lsel.x - win.lsel.w,
            "h": win.lsel.h
        }] : []

        Rectangle {
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: "#b30b0d0c"
        }

    }

    Rectangle {
        visible: win.lsel && shell.phase === "select"
        x: win.lsel ? win.lsel.x : 0
        y: win.lsel ? win.lsel.y : 0
        width: win.lsel ? win.lsel.w : 0
        height: win.lsel ? win.lsel.h : 0
        color: "transparent"
        border.color: shell.accent
        border.width: 1.5
    }

    Text {
        visible: win.lsel && shell.phase === "select"
        x: win.lsel ? win.lsel.x : 0
        y: (win.lsel ? win.lsel.y : 0) - height - 4
        text: Math.round(shell.sel.w) + "×" + Math.round(shell.sel.h)
        color: shell.accent
        font.family: shell.font
        font.pixelSize: 13
    }

    // Window hover highlight + tooltip.
    Rectangle {
        visible: shell.phase === "select" && shell.mode === "window" && win.hoverWin
        x: win.hoverWin ? win.hoverWin.x - mon.x : 0
        y: win.hoverWin ? win.hoverWin.y - mon.y : 0
        width: win.hoverWin ? win.hoverWin.w : 0
        height: win.hoverWin ? win.hoverWin.h : 0
        color: "#29e0563b"
        border.color: shell.accent
        border.width: 2
    }

    Rectangle {
        visible: shell.phase === "select" && shell.mode === "window" && win.hoverWin
        x: Math.min(win.hoverX + 14, win.width - tipText.width - 20)
        y: Math.max(win.hoverY - 44, 8)
        width: tipText.width + 16
        height: tipText.height + 10
        radius: 7
        color: "#e8121110"
        border.width: 1
        border.color: shell.border

        Text {
            id: tipText

            anchors.centerIn: parent
            text: win.hoverWin ? win.hoverWin.app + (win.hoverWin.title ? " — " + win.hoverWin.title.slice(0, 48) : "") : ""
            color: shell.cream
            font.family: shell.font
            font.pixelSize: 12
        }

    }

    // ——— annotate-phase composite (this exact item is the export) ———
    Item {
        id: exportBox

        visible: win.isAnnot
        x: shell.sel.x - mon.x
        y: shell.sel.y - mon.y
        width: shell.sel.w
        height: shell.sel.h

        Image {
            id: capImg

            anchors.fill: parent
            source: shell.capSrc ? "file://" + shell.capSrc : ""
            fillMode: Image.Stretch
            cache: false
            onStatusChanged: {
                if (status === Image.Ready)
                    shell.capReady = true;

            }
        }

        Repeater {
            model: shell.strokes

            ShapeGlyph {
                required property var modelData

                s: modelData
                ox: shell.sel.x
                oy: shell.sel.y
                font: shell.font
            }

        }

        ShapeGlyph {
            visible: shell.draft !== null
            s: shell.draft || {
                "type": "pen",
                "pts": [],
                "color": "#000000",
                "w": 1
            }
            ox: shell.sel.x
            oy: shell.sel.y
            font: shell.font
        }

    }

    Toolbar {
        shell: win.shell
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        visible: win.isAnnot
    }

    TextInput {
        id: editor

        visible: win.isAnnot && shell.textAt !== null
        x: shell.textAt ? shell.textAt.x - mon.x : 0
        y: shell.textAt ? shell.textAt.y - mon.y : 0
        width: Math.max(120, contentWidth + 12)
        color: shell.ink
        font.family: shell.font
        font.pixelSize: 12 + shell.inkW * 2
        cursorVisible: true
        onVisibleChanged: {
            if (visible)
                forceActiveFocus();

        }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                commitEditor();
                e.accepted = true;
            } else if (e.key === Qt.Key_Escape) {
                shell.textAt = null;
                editor.text = "";
                e.accepted = true;
            }
        }
    }

    MouseArea {
        property var dragAnchor: null

        anchors.fill: parent
        enabled: shell.phase === "select" ? win.selecting : win.isAnnot
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: shell.phase === "select" ? Qt.CrossCursor : Qt.ArrowCursor
        onPressed: (m) => {
            var gx = m.x + mon.x, gy = m.y + mon.y;
            if (shell.phase === "select") {
                if (shell.mode === "window") {
                    var c = hitWindow(gx, gy);
                    if (c) {
                        shell.sel = {
                            "valid": true,
                            "x": c.x,
                            "y": c.y,
                            "w": c.w,
                            "h": c.h
                        };
                        shell.toAnnotate();
                    }
                } else {
                    dragAnchor = {
                        "x": gx,
                        "y": gy
                    };
                    shell.sel = {
                        "valid": false,
                        "x": gx,
                        "y": gy,
                        "w": 0,
                        "h": 0
                    };
                }
            } else {
                pressAt(gx, gy);
            }
        }
        onPositionChanged: (m) => {
            var gx = m.x + mon.x, gy = m.y + mon.y;
            if (shell.phase === "select") {
                if (shell.mode === "window") {
                    win.hoverWin = hitWindow(gx, gy);
                    win.hoverX = m.x;
                    win.hoverY = m.y;
                } else if (dragAnchor) {
                    var x0 = Math.min(dragAnchor.x, gx), y0 = Math.min(dragAnchor.y, gy);
                    var w = Math.abs(gx - dragAnchor.x), h = Math.abs(gy - dragAnchor.y);
                    shell.sel = {
                        "valid": w > 8 && h > 8,
                        "x": x0,
                        "y": y0,
                        "w": w,
                        "h": h
                    };
                }
            } else {
                moveTo(gx, gy);
            }
        }
        onReleased: {
            if (shell.phase === "select") {
                if (shell.mode === "region" && shell.sel.valid)
                    shell.toAnnotate();

                dragAnchor = null;
            } else {
                releaseAt();
            }
        }
    }

}
