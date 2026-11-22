pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../lib/eq.js" as Eq

/**
 * Sound state plus the EQ engine. The EQ is a smart filter-chain unit in front
 * of the default output, started as its own pipewire instance and driven live
 * through pw-cli, so anything playing on the system hears the same settings.
 */
Singleton {
    id: root

    readonly property var freqs: Eq.FREQS
    readonly property real range: 12
    readonly property var builtins: [
        { name: "Flat", bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], bass: 0, treble: 0, widen: 0 },
        { name: "Bass", bands: [5, 4, 3, 1, 0, 0, 0, 0, 0, 0], bass: 0, treble: 0, widen: 0 },
        { name: "Vocal", bands: [-2, -2, -1, 0, 2, 3, 3, 2, 0, -1], bass: 0, treble: 0, widen: 0 },
        { name: "HD", bands: [2, 1, 0, 0, -1, 0, 1, 2, 3, 3], bass: 2, treble: 2, widen: 25 },
        { name: "Cinema", bands: [4, 3, 1, 0, -1, 0, 1, 1, 2, 2], bass: 3, treble: 1, widen: 40 }
    ]

    readonly property string conf: Config.hyprPath("sound", "eq.conf")
    readonly property string runner: Config.hyprPath("sound", "eq-run.sh")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima"
    readonly property string pidFile: root.stateDir + "/eq.pid"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ukishima/autoeq"

    property bool eq: false
    property var aeqIndex: []
    property bool aeqLoading: false
    property string aeqError: ""
    property var modes: root.builtins.map(root.copyMode)
    property var devices: ({})

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property string deviceKey: sink ? (sink.name || "") : ""

    /** The running filter's capture node, null while the EQ is off or still starting. */
    readonly property var filterNode: {
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            if (all[i] && all[i].name === "ukishima_eq")
                return all[i];
        }
        return null;
    }

    readonly property var current: root.devices[root.deviceKey] || root.fromMode(root.modes[0] || root.builtins[0])

    function label(node) {
        return node ? (node.description || node.nickname || node.name || "") : "";
    }

    /** Real output devices, never the per-app streams or the EQ filter node. */
    readonly property var outputSinks: {
        const out = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.isSink && !n.isStream && n.audio && n.name !== "ukishima_eq")
                out.push(n);
        }
        out.sort((a, b) => root.label(a).localeCompare(root.label(b)));
        return out;
    }

    /** Real input devices; the sink monitors Pipewire exposes alongside mics are dropped by name. */
    readonly property var inputSources: {
        const out = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && !n.isSink && !n.isStream && n.audio && !/monitor/i.test(n.name || ""))
                out.push(n);
        }
        out.sort((a, b) => root.label(a).localeCompare(root.label(b)));
        return out;
    }

    /** App playback streams, without our own filter output and pw-loopback helpers like DiscordOut. */
    readonly property var apps: {
        const out = [];
        const all = Pipewire.nodes.values;
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && n.isStream && n.isSink && n.audio && n.name !== "ukishima_eq.out" && !/^output\.pw-loopback/.test(n.name || ""))
                out.push(n);
        }
        return out;
    }

    PwObjectTracker {
        id: track
    }

    /** Assigned from code, not a binding: a binding on this typed property re-evaluates to undefined during a config reload and logs a false alarm. */
    function syncTrack() {
        track.objects = [root.sink, root.source].concat(root.apps || []).filter(Boolean);
    }

    onSinkChanged: root.syncTrack()
    onSourceChanged: root.syncTrack()
    onAppsChanged: root.syncTrack()
    readonly property var currentMode: root.findMode(root.current.mode)
    readonly property bool dirty: !root.currentMode || !root.sameSound(root.current, root.currentMode)

    function copyMode(m) {
        return { name: m.name, bands: m.bands.slice(), bass: m.bass, treble: m.treble, widen: m.widen };
    }

    function fromMode(m) {
        return { mode: m.name, bands: m.bands.slice(), bass: m.bass, treble: m.treble, widen: m.widen };
    }

    function findMode(name) {
        for (let i = 0; i < root.modes.length; i++) {
            if (root.modes[i].name === name)
                return root.modes[i];
        }
        return null;
    }

    function sameSound(a, b) {
        if (a.bass !== b.bass || a.treble !== b.treble || a.widen !== b.widen)
            return false;
        for (let i = 0; i < 10; i++) {
            if (a.bands[i] !== b.bands[i])
                return false;
        }
        return true;
    }

    property var undoStack: []
    property string undoKey: ""
    readonly property string undoLabel: root.undoStack.length ? root.undoStack[root.undoStack.length - 1].label : ""

    /** Push an undo step; a keyed change repeated while the coalesce timer runs folds into one step, so a fader drag undoes in one go. */
    function remember(key, label, restore) {
        if (key && key === root.undoKey && undoCoalesce.running) {
            undoCoalesce.restart();
            return;
        }
        root.undoKey = key;
        undoCoalesce.restart();
        root.undoStack = root.undoStack.concat([{ label: label, restore: restore }]).slice(-30);
    }

    /** Snapshot every persisted sound setting plus the output volume before a change, restored as one step. */
    function snapshot(key, label) {
        const snap = JSON.stringify({ eq: root.eq, modes: root.modes, devices: root.devices });
        const sink = root.sink;
        const vol = sink && sink.audio ? sink.audio.volume : -1;
        root.remember(key, label, () => {
            const st = JSON.parse(snap);
            root.eq = st.eq;
            root.modes = st.modes;
            root.devices = st.devices;
            if (vol >= 0 && sink && sink.audio)
                sink.audio.volume = vol;
            root.push();
            root.persist();
        });
    }

    function undo() {
        if (!root.undoStack.length)
            return;
        const step = root.undoStack[root.undoStack.length - 1];
        root.undoStack = root.undoStack.slice(0, -1);
        root.undoKey = "";
        step.restore();
    }

    Timer {
        id: undoCoalesce
        interval: 900
    }

    function setCurrent(next) {
        if (!root.deviceKey)
            return;
        const d = Object.assign({}, root.devices);
        d[root.deviceKey] = next;
        root.devices = d;
        root.push();
        persistLater.restart();
    }

    function setBand(i, db) {
        root.snapshot("band" + i, root.freqs[i] >= 1000 ? (root.freqs[i] / 1000) + "k band" : root.freqs[i] + " Hz band");
        const c = root.current;
        const bands = c.bands.slice();
        bands[i] = db;
        root.setCurrent(Object.assign({}, c, { bands: bands }));
    }

    function setValue(key, v) {
        root.snapshot(key, key.charAt(0).toUpperCase() + key.slice(1));
        root.assign(key, v);
    }

    function assign(key, v) {
        const patch = {};
        patch[key] = v;
        root.setCurrent(Object.assign({}, root.current, patch));
    }

    function pick(name) {
        const m = root.findMode(name);
        root.snapshot("", "Mode");
        if (m)
            root.setCurrent(Object.assign({}, root.current, root.fromMode(m)));
    }

    /** Write the device's current values back into the mode it came from. */
    function save() {
        root.snapshot("", "Save mode");
        const c = root.current;
        root.modes = root.modes.map(m => m.name === c.mode
            ? { name: m.name, bands: c.bands.slice(), bass: c.bass, treble: c.treble, widen: c.widen } : m);
        root.persist();
    }

    /** New mode from the current sound, named "Custom N" with the first free N. */
    function add() {
        root.snapshot("", "New mode");
        let n = 1;
        while (root.findMode("Custom " + n))
            n++;
        const c = root.current;
        const name = "Custom " + n;
        root.modes = root.modes.concat([{ name: name, bands: c.bands.slice(), bass: c.bass, treble: c.treble, widen: c.widen }]);
        root.setCurrent(Object.assign({}, c, { mode: name }));
        root.persist();
    }

    function remove(name) {
        root.snapshot("", "Delete mode");
        root.modes = root.modes.filter(m => m.name !== name);
        root.persist();
    }

    /** Rename a mode and every device that points at it; refuses empty or taken names. */
    function rename(from, to) {
        to = (to || "").trim();
        if (!to || to === from || root.findMode(to))
            return false;
        root.snapshot("", "Rename mode");
        root.modes = root.modes.map(m => m.name === from ? Object.assign({}, m, { name: to }) : m);
        const d = {};
        for (const k in root.devices)
            d[k] = root.devices[k].mode === from ? Object.assign({}, root.devices[k], { mode: to }) : root.devices[k];
        root.devices = d;
        root.persist();
        return true;
    }

    /** Built-in modes come back with their stock values, custom ones stay after them. */
    function restoreDefaults() {
        root.snapshot("", "Reset modes");
        const custom = root.modes.filter(m => !root.builtins.some(b => b.name === m.name));
        root.modes = root.builtins.map(root.copyMode).concat(custom);
        root.persist();
    }

    /** Device boost in percent: extra gain in the filter chain, so the audio is louder without touching the volume level. */
    function setBoost(pct) {
        root.snapshot("", "Boost");
        root.assign("boost", pct);
        root.persist();
    }

    /** Output device a stream plays on, with the EQ filter resolved to the device behind it. */
    function targetOf(stream) {
        const groups = Pipewire.linkGroups.values;
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (g && g.source === stream && g.target)
                return g.target.name === "ukishima_eq" ? root.sink : g.target;
        }
        return null;
    }

    /** Pin a stream to an output, or hand it back to the default when `node` is the default. */
    function route(stream, node) {
        const prev = root.targetOf(stream);
        root.remember("", "App output", () => {
            if (stream)
                root.applyRoute(stream, prev);
        });
        root.applyRoute(stream, node);
    }

    function applyRoute(stream, node) {
        routeProc.command = node && node !== root.sink
            ? ["pw-metadata", String(stream.id), "target.object", node.name]
            : ["pw-metadata", "-d", String(stream.id), "target.object"];
        routeProc.running = true;
    }

    Process {
        id: routeProc
    }

    /** Live PipeWire volume or mute on a stream or source, with an undo step that puts the old value back. */
    function setNodeVolume(node, v, key, label) {
        if (!node || !node.audio)
            return;
        const old = node.audio.volume;
        root.remember(key, label, () => { if (node && node.audio) node.audio.volume = old; });
        node.audio.volume = v;
    }

    function setNodeMuted(node, m) {
        if (!node || !node.audio)
            return;
        const old = node.audio.muted;
        root.remember("", "Mute", () => { if (node && node.audio) node.audio.muted = old; });
        node.audio.muted = m;
    }

    function setEq(on) {
        root.snapshot("", "EQ");
        root.eq = on;
        root.persist();
    }

    /** Filter-chain params for the current sound, with a preamp that pulls boosted bands back under 0 dBFS, plus the device boost. */
    function params() {
        const c = root.current;
        let peak = Math.max(0, c.bass, c.treble);
        const p = [];
        for (let i = 0; i < 10; i++) {
            peak = Math.max(peak, c.bands[i]);
            p.push('"l' + i + ':Gain" ' + c.bands[i], '"r' + i + ':Gain" ' + c.bands[i]);
        }
        p.push('"lb:Gain" ' + c.bass, '"rb:Gain" ' + c.bass, '"lt:Gain" ' + c.treble, '"rt:Gain" ' + c.treble);
        const aeq = c.autoeq;
        const keys = ["b0", "b1", "b2", "a0", "a1", "a2"];
        for (let i = 0; i < 10; i++) {
            const k = aeq && aeq.filters[i] ? Eq.biquad(aeq.filters[i]) : [1, 0, 0, 1, 0, 0];
            for (let j = 0; j < 6; j++)
                p.push('"la' + i + ":" + keys[j] + '" ' + k[j].toFixed(9), '"ra' + i + ":" + keys[j] + '" ' + k[j].toFixed(9));
        }
        const night = c.night === true;
        p.push('"dl:Gain 1" ' + (night ? 0 : 1), '"dl:Gain 2" ' + (night ? 1 : 0), '"dr:Gain 1" ' + (night ? 0 : 1), '"dr:Gain 2" ' + (night ? 1 : 0));
        const w = c.widen / 100;
        const boost = (c.boost || 100) / 100;
        const pre = Math.pow(10, ((aeq ? aeq.preamp : 0) - peak) / 20) / (1 + w / 2) * boost;
        const own = ((1 + w / 2) * pre).toFixed(4);
        const cross = (-w / 2 * pre).toFixed(4);
        p.push('"wl:Gain 1" ' + own, '"wl:Gain 2" ' + cross, '"wr:Gain 1" ' + own, '"wr:Gain 2" ' + cross);
        return "{ params = [ " + p.join(" ") + " ] }";
    }

    /**
     * Load the AutoEQ index, downloading it only when the cached copy is missing
     * or older than 30 days by file mtime. There is no timer or background
     * polling: this runs once, and only when the headphone picker is opened.
     */
    function loadAeqIndex() {
        if (root.aeqIndex.length || root.aeqLoading)
            return;
        root.aeqLoading = true;
        root.aeqError = "";
        aeqIndexProc.running = true;
    }

    function searchAeq(q) {
        const words = (q || "").toLowerCase().split(/\s+/).filter(w => w.length);
        if (!words.length)
            return [];
        const out = [];
        for (let i = 0; i < root.aeqIndex.length && out.length < 40; i++) {
            const e = root.aeqIndex[i];
            const n = e.name.toLowerCase();
            if (words.every(w => n.indexOf(w) >= 0))
                out.push(e);
        }
        const rank = (e) => e.by === "oratory1990" ? 0 : (e.by === "crinacle" ? 1 : 2);
        return out.sort((a, b) => a.name.length - b.name.length || rank(a) - rank(b)).slice(0, 7);
    }

    property var aeqPending: null

    function pickAeq(entry) {
        const seg = entry.path.split("/").pop();
        root.aeqPending = entry;
        root.aeqError = "";
        aeqFetch.command = ["sh", "-c",
            'u="$1"; if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 15 "$u"; '
            + 'else wget -q -T 15 -O - "$u"; fi',
            "sh",
            "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/" + entry.path.slice(2) + "/" + seg + "%20ParametricEQ.txt"];
        aeqFetch.running = true;
    }

    function clearAeq() {
        root.snapshot("", "AutoEQ");
        root.assign("autoeq", null);
        root.persist();
    }

    function setNight(on) {
        root.snapshot("", "Night mode");
        root.assign("night", on);
        root.persist();
    }

    Process {
        id: aeqIndexProc
        command: ["sh", "-c",
            'd="$1"; f="$d/INDEX.md"; mkdir -p "$d"; '
            + 'if [ ! -s "$f" ] || [ -n "$(find "$f" -mtime +30 2>/dev/null)" ]; then '
            + 'if command -v curl >/dev/null 2>&1; then '
            + 'curl -fsSL --max-time 20 -o "$f.tmp" https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md; '
            + 'else wget -q -T 20 -O "$f.tmp" https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/INDEX.md; fi '
            + '&& mv "$f.tmp" "$f"; fi; '
            + 'cat "$f" 2>/dev/null', "_", root.cacheDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = Eq.parseIndex(this.text);
                root.aeqIndex = out;
                root.aeqLoading = false;
                if (!out.length)
                    root.aeqError = "Could not load the headphone list";
            }
        }
    }

    Process {
        id: aeqFetch
        stdout: StdioCollector {
            onStreamFinished: {
                const profile = Eq.parseProfile(this.text);
                const e = root.aeqPending;
                root.aeqPending = null;
                if (!e || !profile) {
                    root.aeqError = "Could not load that profile";
                    return;
                }
                root.snapshot("", "AutoEQ");
                root.assign("autoeq", { name: e.name, by: e.by, preamp: profile.preamp, filters: profile.filters });
                root.persist();
            }
        }
    }

    property bool pushPending: false

    function push() {
        if (root.filterNode)
            pushDebounce.restart();
    }

    onFilterNodeChanged: root.push()
    onDeviceKeyChanged: root.push()

    Timer {
        id: pushDebounce
        interval: 20
        onTriggered: {
            if (paramProc.running) {
                root.pushPending = true;
                return;
            }
            if (!root.filterNode)
                return;
            paramProc.command = ["pw-cli", "set-param", String(root.filterNode.id), "Props", root.params()];
            paramProc.running = true;
        }
    }

    Process {
        id: paramProc
        onExited: {
            if (root.pushPending) {
                root.pushPending = false;
                pushDebounce.restart();
            }
        }
    }

    /**
     * Start or stop the EQ filter chain. sound/eq-run.sh owns the chain: it
     * runs `pipewire -c eq.conf` detached (so a shell reload leaves it alone)
     * and stops it once this shell process exits, so nothing is left behind in
     * the graph and no service unit is needed. Idempotent: a pidfile marks the
     * live chain, so repeated calls do not stack a duplicate.
     */
    function engine() {
        engineProc.running = false;
        engineProc.command = ["sh", "-c",
            'conf="$1"; run="$2"; pid="$3"; '
            + 'if [ "$4" = 1 ]; then '
            + 'if [ -r "$pid" ] && kill -0 "$(cat "$pid")" 2>/dev/null; then exit 0; fi; '
            + 'setsid -f sh "$run" "$conf" "$PPID" "$pid" >/dev/null 2>&1; '
            + 'else '
            + 'if [ -r "$pid" ]; then kill "$(cat "$pid")" 2>/dev/null; rm -f "$pid"; fi; '
            + 'pkill -f "pipewire -c $conf" 2>/dev/null; '
            + 'fi',
            "sh", root.conf, root.runner, root.pidFile, root.eq ? "1" : "0"];
        engineProc.running = true;
    }

    property int misses: 0

    onEqChanged: {
        root.misses = 0;
        root.engine();
    }

    /**
     * Safety net for a reload or a crash: while the EQ is on but the filter
     * node is missing from the graph, bring the chain back. Uses the node, not
     * the launcher process, so it stops as soon as the chain is really up.
     * The miss cap matters on a machine without PipeWire: `pipewire -c` fails
     * at once there, so an uncapped retry would spawn a process every second.
     */
    Timer {
        interval: 1000
        repeat: true
        // Literal, not a binding: a binding here re-evaluates to undefined during a config reload and logs a false alarm.
        running: true
        onTriggered: {
            if (!root.eq || root.filterNode) {
                root.misses = 0;
            } else if (root.misses < 10) {
                root.misses++;
                root.engine();
            }
        }
    }

    Process {
        id: engineProc
    }

    function persist() {
        file.setText(JSON.stringify({ eq: root.eq, modes: root.modes, devices: root.devices }));
    }

    Timer {
        id: persistLater
        interval: 600
        onTriggered: root.persist()
    }

    Component.onCompleted: {
        try {
            const s = JSON.parse(file.text());
            root.eq = s.eq === true;
            if (Array.isArray(s.modes) && s.modes.length)
                root.modes = s.modes;
            if (s.devices && typeof s.devices === "object")
                root.devices = s.devices;
        } catch (e) {}
        root.syncTrack();
        // Setting eq from the file fires onEqChanged, which is the single place
        // that starts or stops the chain; calling engine() here too would race
        // the pgrep guard and could spawn a second instance.
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: file
        path: root.stateDir + "/sound.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }
}
