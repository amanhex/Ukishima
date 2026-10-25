pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var seenIds: ({})
    property var arrivalMs: ({})
    property var popups: []
    property int tick: 0
    property var expandedApps: ({})
    property var history: []
    property var userDismissed: ({})
    property var expireAt: ({})
    property var hookedIds: ({})

    readonly property var tracked: server.trackedNotifications.values
    readonly property int count: tracked.length + history.length

    /** The toast actually shown is the newest popup; critical flags whether it must never be covered. */
    readonly property bool toastCritical: {
        var p = popups;
        return p.length > 0 && p[p.length - 1].urgency === NotificationUrgency.Critical;
    }

    readonly property int unread: {
        var u = 0;
        for (var i = 0; i < tracked.length; i++)
            if (!seenIds[tracked[i].id]) u++;
        return u;
    }

    readonly property var groups: {
        var map = {};
        var order = [];
        for (var i = 0; i < tracked.length; i++) {
            var n = tracked[i];
            var app = (n.appName && n.appName.length) ? n.appName : "System";
            if (map[app] === undefined) { map[app] = []; order.push(app); }
            map[app].push({ live: true, n: n, t: arrivalMs[n.id] || 0 });
        }
        for (var j = 0; j < history.length; j++) {
            var h = history[j];
            if (map[h.app] === undefined) { map[h.app] = []; order.push(h.app); }
            map[h.app].push({ live: false, n: h, t: h.ts || 0 });
        }
        function coalesce(list, it) {
            var last = list.length > 0 ? list[list.length - 1] : null;
            if (last && last.n.summary === it.n.summary && last.n.body === it.n.body) {
                last.count++;
                last.items.push(it.n);
            } else {
                list.push({ live: it.live, n: it.n, count: 1, items: [it.n] });
            }
        }
        var gs = order.map(function(app) {
            var items = map[app];
            items.sort(function(a, b) { return b.t - a.t; });
            var criticals = [];
            var entries = [];
            for (var k = 0; k < items.length; k++)
                coalesce(items[k].n.urgency === NotificationUrgency.Critical ? criticals : entries, items[k]);
            var preview = items.find(function(it) { return it.n.urgency !== NotificationUrgency.Critical; });
            return {
                app: app,
                count: items.length,
                t: items[0].t,
                newest: items[0].n,
                preview: preview ? preview.n : items[0].n,
                criticals: criticals,
                entries: entries
            };
        });
        gs.sort(function(a, b) { return b.t - a.t; });
        return gs;
    }

    function iconFor(n) {
        if (!n) return "";
        var img = n.image || "";
        var names = [];
        if (img.indexOf("image://icon/") === 0) {
            names.push(img.substring(13));
        } else if (img.length && !/\.svg$/i.test(img)) {
            return img;
        }
        names.push(n.appIcon, n.desktopEntry, (n.appName || n.app || "").toLowerCase());
        for (var i = 0; i < names.length; i++) {
            var nm = names[i];
            if (!nm || !nm.length) continue;
            if (nm.indexOf("/") === 0 || nm.indexOf("file://") === 0) return nm;
            var p = Quickshell.iconPath(nm, true);
            if (p.length) return p;
        }
        return "";
    }

    /**
     * Reduce a notification image to something that still resolves after the
     * notification is gone, or "" if nothing about it will.
     *
     * A Notification's `image` is a Quickshell image-provider handle --
     * image://qsimage/<provider>/<request> -- and the provider owns the pixels.
     * The handle lives exactly as long as the Notification object does: on
     * close, Quickshell frees the image and that handle is dead permanently. It
     * is not a path and nothing can re-derive it.
     *
     * That is a trap for the history specifically, because the snapshot is taken
     * from inside the `closed` handler -- the precise instant the handle dies.
     * Storing it there produced a permanently broken source. Worse, it took the
     * early return in iconFor(), so the row never fell back to the themed app
     * icon: the Image stayed `visible` on a non-empty source, loaded nothing,
     * and the fallback dot beside it is keyed off `!image.visible`, so the tile
     * rendered blank. Every re-render of that row logged "unknown handle", and
     * because clearing filters the history and thereby rebuilds those rows, one
     * clear re-requested every dead handle at once. Hence it arriving in bursts
     * on clear.
     *
     * So a handle is never persisted. These do resolve on their own later, with
     * no live object behind them, and are kept: a theme icon name, which
     * iconFor() turns into a path via Quickshell.iconPath; a file:// URL or
     * absolute path; and any other absolute URL (http, qrc). Everything else is
     * dropped, and iconFor() falls through to appIcon / desktopEntry / the app
     * name, which is the icon the user would have seen regardless.
     */
    function durableImage(u) {
        var s = (u === undefined || u === null) ? "" : String(u);
        if (s.length === 0)
            return "";
        // Case-insensitive: URL schemes are, and the invariant that matters is
        // that no handle is ever persisted, so it must not depend on the casing
        // the provider happens to emit. (The icon-name test below stays
        // case-sensitive to match iconFor(), which reads it the same way.)
        if (/^image:\/\/qsimage\//i.test(s))
            return "";
        if (s.indexOf("image://icon/") === 0)
            return s;
        if (s.indexOf("file://") === 0 || s.indexOf("/") === 0)
            return s;
        if (/^[a-z][a-z0-9+.-]*:/i.test(s))
            return s;
        return "";
    }

    /**
     * Blank the dead handles out of history snapshotted before durableImage()
     * existed, so a session already holding them stops re-requesting on every
     * rebuild. Called from the server's onCompleted, which `keepOnReload` re-runs
     * on each reload, so a live shell picks this up on its next reload rather
     * than needing a restart. A no-op once history is empty or already clean.
     */
    function scrubHistory() {
        var h = root.history;
        if (!h || h.length === 0)
            return;
        var out = [];
        var changed = false;
        for (var i = 0; i < h.length; i++) {
            var d = root.durableImage(h[i].image);
            if (d === h[i].image) {
                out.push(h[i]);
            } else {
                changed = true;
                out.push(Object.assign({}, h[i], { image: d }));
            }
        }
        if (changed)
            root.history = out;
    }

    function dismissEntry(e) {
        if (!e || !e.items) return;
        var d = Object.assign({}, userDismissed);
        var gone = {};
        var live = [];
        for (var i = 0; i < e.items.length; i++) {
            var n = e.items[i];
            if (typeof n.dismiss === "function") {
                d[n.id] = true;
                live.push(n);
            } else {
                gone[n.id] = true;
            }
        }
        root.userDismissed = d;
        for (var j = 0; j < live.length; j++) live[j].dismiss();
        root.history = root.history.filter(function(h) { return !gone[h.id]; });
    }

    /**
     * Focus the app's window (workspace switch included) by matching the
     * notification's desktopEntry/appName against the live window classes. Goes
     * through the compositor seam so it works on niri as well as Hyprland.
     */
    function raiseWindow(n) {
        if (!n) return;
        var token = String(n.desktopEntry && n.desktopEntry.length ? n.desktopEntry : (n.appName || "")).toLowerCase();
        if (token.length === 0) return;
        var bare = token.replace(/\.desktop$/, "");
        var wins = Wm.windows || [];
        for (var i = 0; i < wins.length; i++) {
            var app = String(wins[i].appId || "").toLowerCase();
            if (app.indexOf(bare) >= 0) {
                Wm.focusWindow(wins[i]);
                return;
            }
        }
    }

    /**
     * Open the app behind a notification: invoke its default action when present,
     * then jump to the app's window, mirroring stock notification-center behavior.
     */
    function activateNotif(n) {
        if (!n) return;
        var acts = n.actions || [];
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") {
                acts[i].invoke();
                break;
            }
        }
        raiseWindow(n);
    }

    /** Inbox-row entry wrapper: activate the app, then dismiss the entry. */
    function activateEntry(e) {
        if (!e || !e.n) return;
        activateNotif(e.n);
        dismissEntry(e);
    }

    function dismissApp(app) {
        var doomed = tracked.filter(function(n) {
            return ((n.appName && n.appName.length) ? n.appName : "System") === app;
        });
        var d = Object.assign({}, userDismissed);
        for (var i = 0; i < doomed.length; i++) d[doomed[i].id] = true;
        root.userDismissed = d;
        for (var j = 0; j < doomed.length; j++) doomed[j].dismiss();
        root.history = root.history.filter(function(h) { return h.app !== app; });
    }

    function markAllSeen() {
        var m = {};
        for (var i = 0; i < tracked.length; i++) m[tracked[i].id] = true;
        root.seenIds = m;
    }

    function clearAll() {
        var l = tracked.slice();
        var d = Object.assign({}, userDismissed);
        for (var i = 0; i < l.length; i++) d[l[i].id] = true;
        root.userDismissed = d;
        for (var j = 0; j < l.length; j++) l[j].dismiss();
        root.history = [];
        root.popups = [];
    }

    function removePopup(n) {
        root.popups = root.popups.filter(function(p) { return p !== n; });
    }

    /**
     * Drop every pending popup at once. Used when a transient OSD covers a
     * non-critical toast: the toast is retired permanently instead of
     * reappearing when the OSD ends and looking like a second notification.
     * The notification itself stays tracked, so the inbox and unread dot
     * still show it.
     */
    function clearPopups() {
        root.popups = [];
    }

    function toggleExpanded(app) {
        var e = Object.assign({}, expandedApps);
        e[app] = e[app] !== true;
        root.expandedApps = e;
    }

    /**
     * Bind the history-snapshot handler to a notification's `closed` signal once.
     * `keepOnReload` re-runs Component.onCompleted on every QS reload over the
     * still-tracked notifications, so the id set gates re-hooks: without it each
     * reload would stack another handler and a single close would push duplicate
     * history rows. The id is cleared inside the handler so a later notification
     * reusing the id re-hooks cleanly.
     */
    function hookClosed(n) {
        if (root.hookedIds[n.id])
            return;
        var hooked = Object.assign({}, root.hookedIds);
        hooked[n.id] = true;
        root.hookedIds = hooked;
        n.closed.connect(function(reason) {
            if (!root.userDismissed[n.id])
                root.history = [{
                    app: (n.appName && n.appName.length) ? n.appName : "System",
                    summary: n.summary,
                    body: n.body,
                    appIcon: n.appIcon,
                    desktopEntry: n.desktopEntry,
                    // Never n.image raw: it is a provider handle that this very
                    // handler is firing on the close that kills it. See
                    // durableImage() -- storing it raw left every history row
                    // pointing at a freed image.
                    image: root.durableImage(n.image),
                    urgency: n.urgency,
                    ts: root.arrivalMs[n.id] || Date.now(),
                    id: "h" + n.id + "-" + Date.now()
                }].concat(root.history).slice(0, 50);
            else {
                var du = Object.assign({}, root.userDismissed);
                delete du[n.id];
                root.userDismissed = du;
            }
            root.removePopup(n);
            var b = Object.assign({}, root.arrivalMs);
            delete b[n.id];
            root.arrivalMs = b;
            var c = Object.assign({}, root.expireAt);
            delete c[n.id];
            root.expireAt = c;
            var h = Object.assign({}, root.hookedIds);
            delete h[n.id];
            root.hookedIds = h;
        });
    }

    function ageLabel(n) {
        void root.tick;
        var t = arrivalMs[n.id] || n.ts;
        if (!t) return "";
        var m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        return Math.floor(m / 60) + "h";
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.tick++
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        Component.onCompleted: {
            root.scrubHistory();
            var l = trackedNotifications.values;
            var a = Object.assign({}, root.arrivalMs);
            for (var i = 0; i < l.length; i++) {
                if (!a[l[i].id]) a[l[i].id] = Date.now();
                root.hookClosed(l[i]);
            }
            root.arrivalMs = a;
        }

        onNotification: function(n) {
            var a = Object.assign({}, root.arrivalMs);
            a[n.id] = Date.now();
            root.arrivalMs = a;
            var e = Object.assign({}, root.expireAt);
            e[n.id] = Date.now() + (n.urgency === NotificationUrgency.Low ? 2500 : 3000);
            root.expireAt = e;
            n.tracked = true;
            root.hookClosed(n);
            var critical = n.urgency === NotificationUrgency.Critical;
            if (!Flags.dnd || critical)
                root.popups = root.popups.concat([n]).slice(-3);
        }
    }
}
