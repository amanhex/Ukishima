import QtQuick
import Quickshell
import Quickshell.Io

/**
 * 撮 Screenshot studio root. A SEPARATE config (`qs -c shot`), launched only
 * via scripts/shot.sh — never part of the main shell's import graph, sharing
 * no singletons and no Theme. All styling is hardcoded below to match the
 * pill (warm near-black, cream, vermilion), so this process is fully
 * self-contained and quits when the capture lands.
 *
 * Modes come from the SHOT_MODE env (screen|region|window|color):
 * screen shoots a monitor straight away with no overlay; color runs
 * hyprpicker, which copies the hex itself. Region and window freeze every
 * output first (grim stills, one per monitor — the lock.sh pre-capture
 * pattern) and select on the still, so no picker ever fights the overlay
 * for the pointer. A resolved selection hides the overlays, re-captures the
 * exact pixels with `grim -g`, and annotates over that file; export is a
 * grabToImage of the annotated pixels, so what you see is the PNG.
 *
 * Geometry everywhere is compositor (logical) pixels: hyprctl reports them,
 * QML mouse lands in them, and grim takes them. HiDPI stills render
 * downscaled in the overlay, but the export grabs at device pixels, so the
 * saved file stays full-resolution with the strokes scaled along.
 */
ShellRoot {
    id: root

    readonly property string mode: Quickshell.env("SHOT_MODE") || "region"
    readonly property string shotMon: Quickshell.env("SHOT_MON") || ""
    readonly property string shotDir: Quickshell.env("SHOT_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots")
    readonly property string tmpDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima-shot"
    // Self-contained palette (mirrors Theme: cardBot, cream, vermLit...).
    readonly property color bg: "#121110"
    readonly property color card: "#1d1a17"
    readonly property color cream: "#f2ede4"
    readonly property color subtle: "#a8a094"
    readonly property color accent: "#e0563b"
    readonly property color border: "#ffffff1f"
    readonly property string font: "JetBrainsMono Nerd Font"
    //* Monitors as {name,x,y,w,h}; stills maps connector name to its freeze PNG.
    property var monitors: []
    property var stills: ({
    })
    //* Clients as {app,title,x,y,w,h}, most-recently-focused first.
    property var clients: []
    //* boot → select → annotate; busy hides the overlays for a clean grim.
    property string phase: "boot"
    //* Selection in global coords; valid once it has a real area.
    property var sel: ({
        "valid": false,
        "x": 0,
        "y": 0,
        "w": 0,
        "h": 0
    })
    //* Connector showing the annotation stage.
    property string annotScreen: ""
    property string tool: "pen"
    property string ink: "#e0563b"
    property int inkW: 4
    //* Committed strokes in global coords; draft is the in-progress one.
    property var strokes: []
    property var draft: null
    //* Click point for the text editor, global coords, or null.
    property var textAt: null
    //* grim re-capture of the selection; the annotation Image shows this.
    property string tmpCap: ""
    //* tmpCap gated on grim finishing, so the Image never loads a half-file.
    property string capSrc: ""
    property bool capReady: false
    property string status: ""
    //* First: monitor geometry (and the focused monitor for screen mode).
    property string bootNext: ""
    //* Region/window: freeze every output, then list clients, then select.
    property int freezeIdx: 0
    /** Test doors (env only, unset in production): SHOT_TEST_GEOM auto-resolves
     * a selection as `x,y WxH` on entering select; SHOT_TEST_DRAW stamps one
     * of every stroke kind across it on entering annotate. Together with
     * wtype they drive the whole pipeline with no pointer. */
    readonly property string testGeom: Quickshell.env("SHOT_TEST_GEOM") || ""
    readonly property bool testDraw: (Quickshell.env("SHOT_TEST_DRAW") || "") === "1"

    signal saveRequested()

    function monFor(name) {
        for (var i = 0; i < monitors.length; i++) if (monitors[i].name === name) {
            return monitors[i];
        }
        return null;
    }

    function screenAt(gx, gy) {
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i];
            if (gx >= m.x && gx < m.x + m.w && gy >= m.y && gy < m.y + m.h)
                return m;

        }
        return monitors.length ? monitors[0] : null;
    }

    function timestamp() {
        function p(n, l) {
            return String(n).padStart(l || 2, "0");
        }

        var d = new Date();
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "_" + p(d.getHours()) + "-" + p(d.getMinutes()) + "-" + p(d.getSeconds());
    }

    function outPath() {
        return shotDir + "/shot_" + timestamp() + ".png";
    }

    function geomStr() {
        return Math.round(sel.x) + "," + Math.round(sel.y) + " " + Math.round(sel.w) + "x" + Math.round(sel.h);
    }

    function notify(summary, body) {
        noteProc.command = ["notify-send", summary, body || ""];
        noteProc.running = true;
    }

    function fail(msg) {
        root.status = msg;
        notify("Screenshot failed", msg);
        Qt.quit();
    }

    function bootMonitors(next) {
        bootNext = next;
        monProc.running = true;
    }

    function freezeAll() {
        freezeIdx = 0;
        if (!monitors.length) {
            fail("no monitors found");
            return ;
        }
        freezeOne();
    }

    function stillName(connector) {
        return tmpDir + "/still-" + connector.replace(/[^A-Za-z0-9-]+/g, "_") + ".png";
    }

    function freezeOne() {
        if (freezeIdx >= monitors.length) {
            clientProc.running = true;
            return ;
        }
        var m = monitors[freezeIdx];
        // The path publishes in onExited, after grim has written it: an
        // Image pointed at a not-yet-existing file errors once and never
        // retries, which used to wedge the select gate shut behind it.
        grimStill.command = ["grim", "-o", m.name, stillName(m.name)];
        grimStill.running = true;
    }

    function beginSelect() {
        phase = "select";
        if (testGeom) {
            var parts = testGeom.split(" ");
            var xy = parts[0].split(","), wh = parts[1].split("x");
            sel = {
                "valid": true,
                "x": +xy[0],
                "y": +xy[1],
                "w": +wh[0],
                "h": +wh[1]
            };
            testTimer.start();
        }
    }

    //* A valid selection resolves: hide everything, grim the exact pixels.
    function toAnnotate() {
        if (!sel.valid)
            return ;

        strokes = [];
        draft = null;
        textAt = null;
        capReady = false;
        tmpCap = tmpDir + "/cap.png";
        phase = "busy";
        var c = screenAt(sel.x + sel.w / 2, sel.y + sel.h / 2);
        annotScreen = c ? c.name : monitors[0].name;
        grimCap.command = ["grim", "-g", geomStr(), tmpCap];
        grimCap.running = true;
    }

    function backToSelect() {
        sel = {
            "valid": false,
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0
        };
        strokes = [];
        draft = null;
        textAt = null;
        phase = "select";
    }

    function addStroke(s) {
        strokes = strokes.concat([s]);
    }

    function undo() {
        if (draft) {
            draft = null;
            return ;
        }
        if (strokes.length)
            strokes = strokes.slice(0, strokes.length - 1);

    }

    function doSave() {
        if (!capReady)
            return ;

        status = "";
        saveRequested();
    }

    function onExportSaved(path) {
        copyProc.command = ["sh", "-c", 'wl-copy -t image/png < "$1"', "_", path];
        copyProc.pendingPath = path;
        copyProc.running = true;
    }

    function onExportFailed() {
        status = "export failed — retry or Esc";
        phase = "annotate";
    }

    function doQuit() {
        Qt.quit();
    }

    function screenShoot() {
        var target = shotMon;
        if (!target) {
            for (var i = 0; i < monitors.length; i++) if (monitors[i].focused) {
                target = monitors[i].name;
            }
        }
        if (!target && monitors.length)
            target = monitors[0].name;

        if (!target) {
            fail("no monitors found");
            return ;
        }
        var path = outPath();
        screenProc.pendingPath = path;
        screenProc.command = target === "all" ? ["grim", path] : ["grim", "-o", target, path];
        screenProc.running = true;
    }

    //* Color: hyprpicker copies the hex itself; report what landed.
    function pickColor() {
        colorProc.running = true;
    }

    Component.onCompleted: {
        if (mode === "screen")
            bootMonitors("screen");
        else if (mode === "color")
            pickColor();
        else
            bootMonitors("overlay");
    }

    Timer {
        id: testTimer

        interval: 400
        repeat: false
        onTriggered: root.toAnnotate()
    }

    Process {
        id: monProc

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                var mons = [];
                try {
                    var arr = JSON.parse(text);
                    for (var i = 0; i < arr.length; i++) {
                        var m = arr[i];
                        mons.push({
                            "name": m.name,
                            "x": m.x,
                            "y": m.y,
                            "w": m.width,
                            "h": m.height,
                            "scale": m.scale || 1,
                            "focused": !!m.focused
                        });
                    }
                } catch (e) {
                    root.fail("monitor list failed");
                    return ;
                }
                root.monitors = mons;
                if (root.bootNext === "screen")
                    root.screenShoot();
                else
                    root.freezeAll();
            }
        }

    }

    Process {
        id: grimStill

        onExited: (code) => {
            // Publish after the write, even on failure: the overlay shows
            // dark for a failed still but selection still resolves (the
            // grim -g re-capture is the pixels that ship). Count up always,
            // never stall.
            var m = root.monitors[root.freezeIdx];
            if (m) {
                root.stills[m.name] = root.stillName(m.name);
                // QML var maps do not notify; reassign so overlays reload.
                root.stills = Object.assign({
                }, root.stills);
            }
            root.freezeIdx += 1;
            root.freezeOne();
        }

        stdout: StdioCollector {
        }

    }

    Process {
        // No window list is not fatal: region select still works.

        id: clientProc

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                try {
                    var arr = JSON.parse(text);
                    arr.sort(function(a, b) {
                        return (b.focusHistoryID || 0) - (a.focusHistoryID || 0);
                    });
                    for (var i = 0; i < arr.length; i++) {
                        var c = arr[i];
                        if (!c || !c.size || !c.at || c.size[0] <= 0 || c.size[1] <= 0)
                            continue;

                        out.push({
                            "app": c.class || "?",
                            "title": c.title || "",
                            "x": c.at[0],
                            "y": c.at[1],
                            "w": c.size[0],
                            "h": c.size[1]
                        });
                    }
                } catch (e) {
                }
                root.clients = out;
                root.beginSelect();
            }
        }

    }

    Process {
        id: screenProc

        property string pendingPath: ""

        onExited: (code) => {
            if (code !== 0) {
                root.fail("grim exited " + code);
                return ;
            }
            root.onExportSaved(screenProc.pendingPath);
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: colorProc

        command: ["hyprpicker", "-a"]
        onExited: (code) => {
            // Escape aborts hyprpicker silently (no stdout): quit with nothing.
            Qt.quit();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var hex = text.trim().split("\n").filter(function(l) {
                    return l.length;
                });
                var last = hex.length ? hex[hex.length - 1] : "";
                root.notify("Color " + (last || "picked"), last ? "copied to clipboard" : "");
                Qt.quit();
            }
        }

    }

    Process {
        id: grimCap

        onExited: (code) => {
            if (code !== 0) {
                root.status = "capture failed — Esc to retry";
                root.phase = "select";
                return ;
            }
            if (root.testDraw) {
                var x = root.sel.x, y = root.sel.y, w = root.sel.w, h = root.sel.h;
                root.addStroke({
                    "type": "pen",
                    "pts": [[x + 20, y + 20], [x + w - 20, y + h - 20]],
                    "color": "#e0563b",
                    "w": 4
                });
                root.addStroke({
                    "type": "rect",
                    "pts": [[x + 30, y + 30], [x + w - 30, y + h - 30]],
                    "color": "#e8b93e",
                    "w": 3
                });
                root.addStroke({
                    "type": "arrow",
                    "pts": [[x + 40, y + h - 40], [x + w - 40, y + 40]],
                    "color": "#7fb069",
                    "w": 4
                });
                root.addStroke({
                    "type": "text",
                    "pts": [[x + 50, y + 50]],
                    "color": "#f2ede4",
                    "w": 4,
                    "size": 20,
                    "text": "test"
                });
            }
            root.capSrc = root.tmpCap;
            root.phase = "annotate";
        }

        stdout: StdioCollector {
        }

    }

    Process {
        id: copyProc

        property string pendingPath: ""

        onExited: (code) => {
            var p = copyProc.pendingPath;
            if (code !== 0)
                root.notify("Screenshot saved", p + " (copy failed)");
            else
                root.notify("Screenshot saved", p);
            Qt.quit();
        }

        stdout: StdioCollector {
        }

        stderr: StdioCollector {
        }

    }

    Process {
        id: noteProc
    }

    Variants {
        id: overlays

        model: (mode === "region" || mode === "window") ? Quickshell.screens : []

        Overlay {
            shell: root
        }

    }

}
