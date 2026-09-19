pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Local calendar events, persisted as a plain JSON array beside the session
 * flags (~/.local/state/ukishima/events.json). The in-memory `events` is the
 * source of truth: add/remove mutate it and write the file, which is read back
 * only at startup. The file is deliberately NOT watched — re-reading our own
 * write races the FileView's cached text and dropped the just-added event (it
 * flashed in, then vanished until the next write). The file holds an array
 * of { id, date, endDate, time, endTime, text, recur } with date/endDate as
 * "YYYY-MM-DD". endDate is "" for a single-day entry, otherwise the last day a
 * multi-day span covers. time and endTime may be "" for an all-day or open-ended
 * entry. Because the keys are zero-padded "YYYY-MM-DD", a plain string compare
 * orders and spans dates correctly, so coverage tests need no Date parsing.
 *
 * recur is "" for a one-off, "year" for a yearly entry (a birthday: shows on its
 * month and day in every year, matched on the "MM-DD" tail) or "month" (shows on
 * its day in every month, matched on the "DD" tail). A recurring entry ignores its
 * endDate. Day 31 monthly and Feb 29 yearly only land where the day exists, which
 * is fine for now. On load, entries written before this field are classified once:
 * a birthday-looking title becomes yearly, the legacy yearly flag folds into recur,
 * the rest stay one-off, and the healed list is persisted so it sticks.
 *
 * A bare array is simpler than a JsonAdapter for a growing list: read the text,
 * JSON.parse, mutate the array, JSON.stringify back through setText. Every parse
 * is guarded so a truncated or corrupt file never throws and never wipes the
 * singleton — a bad read just leaves the last good `events` in place.
 *
 * Ids come from a monotonic counter seeded past the highest id already on disk,
 * never Date.now() or Math.random() (both throw in this engine), so every add is
 * uniquely addressable for remove() even within the same minute.
 *
 * Reminders are not polled. One one-shot Timer is armed for the exact
 * millisecond of the next reminder instant, so an idle shell holds a single
 * dormant OS timer instead of a periodic tick. A timed event yields two
 * instants per occurrence (its start time and, when set, its end time); an
 * all-day event yields one instant per covered day at allDayReminderTime. On
 * fire the event(s) whose instant landed are announced through notify-send,
 * then the timer re-arms for the following one; add/remove/reload re-arm the
 * same timer. A target further out than the QML Timer's ~24.8-day ceiling arms
 * at the ceiling and re-arms on that early wake. An all-day entry with no endDate
 * covers one day; a span covers every day it includes.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/pill"

    property var events: []
    property int nextId: 1

    /**
     * Birthday-looking titles across the languages Erik's contacts use, so a new
     * entry can suggest yearly and old ones get classified on load. Plain substring
     * alternation, case-insensitive; accented forms are caught by a safe stem.
     */
    readonly property var birthdayRe: /geburtstag|geb\.|birthday|b-?day|🎂|cumplea|anniversaire|compleanno|anivers|verjaardag|рожд|誕生|생일|urodziny|do[ğg]um/i

    function isBirthday(t) {
        return root.birthdayRe.test(t || "");
    }

    /**
     * Re-read the file text into `events` and advance the id counter past every
     * id present, so a freshly added event can never collide with one loaded
     * from disk. A FileNotFound or malformed body is treated as an empty list.
     * Entries that predate the recurrence field get classified once and the healed
     * list is written back, so existing birthdays become yearly without a re-entry.
     */
    function reloadEvents() {
        var arr = [];
        try {
            var t = file.text();
            if (t && t.trim().length > 0) {
                var parsed = JSON.parse(t);
                if (Array.isArray(parsed))
                    arr = parsed;
            }
        } catch (e) {
            arr = [];
        }
        var maxId = 0;
        var healed = false;
        for (var i = 0; i < arr.length; i++) {
            var n = Number(arr[i].id);
            if (n > maxId)
                maxId = n;
            var e = arr[i];
            if (e.recur === undefined) {
                e.recur = e.yearly === true ? "year" : (root.isBirthday(e.text) ? "year" : "");
                delete e.yearly;
                healed = true;
            }
        }
        root.nextId = maxId + 1;
        root.events = arr;
        if (healed)
            root.persist();
    }

    function persist() {
        file.setText(JSON.stringify(root.events));
    }

    /** Last day an event covers: its endDate, or its start when single-day. */
    function lastDay(e) {
        return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
    }

    function covers(e, dateStr) {
        if (e.recur === "year")
            return dateStr.slice(5) === e.date.slice(5);
        if (e.recur === "month")
            return dateStr.slice(8) === e.date.slice(8);
        return dateStr >= e.date && dateStr <= root.lastDay(e);
    }

    /** Events covering `dateStr`, sorted by start time; an empty time sorts first. */
    function forDate(dateStr) {
        var out = root.events.filter(function (e) { return root.covers(e, dateStr); });
        out.sort(function (a, b) {
            var at = a.time || "";
            var bt = b.time || "";
            if (at === bt)
                return 0;
            if (at === "")
                return -1;
            if (bt === "")
                return 1;
            return at < bt ? -1 : 1;
        });
        return out;
    }

    function hasEvents(dateStr) {
        for (var i = 0; i < root.events.length; i++) {
            if (root.covers(root.events[i], dateStr))
                return true;
        }
        return false;
    }

    /** Append an event and persist; reassigns `events` so bindings refresh. */
    function add(dateStr, endDate, time, endTime, text, recur) {
        var next = root.events.slice();
        next.push({
            id: root.nextId,
            date: dateStr,
            endDate: endDate || "",
            time: time || "",
            endTime: endTime || "",
            text: text || "",
            recur: recur || ""
        });
        root.nextId += 1;
        root.events = next;
        root.persist();
        root.armReminder();
    }

    function remove(id) {
        root.events = root.events.filter(function (e) { return e.id !== id; });
        root.persist();
        root.armReminder();
    }

    /* --- Reminders -----------------------------------------------------------
     * One one-shot OS timer, not a poll: armed to the exact millisecond of the
     * next reminder instant. A timed event yields two instants per occurrence
     * (its start time and, when set, its end time); an all-day event yields one
     * instant per covered day at allDayReminderTime. On fire the event(s) whose
     * instant landed are announced via notify-send, then the timer re-arms for
     * the following instant; add/remove re-arm. A target further out than the
     * QML Timer's ~24.8-day ceiling arms at the ceiling and re-arms on that
     * early wake — still a single OS timer, still no polling.
     */

    property var armedFor: null // { at, kind } of the armed instant
    readonly property int maxTimerMs: 2147483647

    /** When an all-day event is announced — the instant is its day start. */
    readonly property string allDayReminderTime: "0:00"

    /** Epoch ms for an "HH:MM" time on a calendar day. */
    function stampAt(time, y, m, d) {
        var p = (time || "0:00").split(":");
        return new Date(y, m, d, Number(p[0]), Number(p[1]), 0, 0).getTime();
    }

    /** { y, m, d } of a "YYYY-MM-DD" key. */
    function dayParts(key) {
        return { y: Number(key.slice(0, 4)), m: Number(key.slice(5, 7)) - 1,
                 d: Number(key.slice(8, 10)) };
    }

    /** "YYYY-MM-DD" for a { y, m, d }. */
    function dayKey(p) {
        var mm = p.m + 1;
        return p.y + "-" + (mm < 10 ? "0" + mm : "" + mm)
            + "-" + (p.d < 10 ? "0" + p.d : "" + p.d);
    }

    /** The day after a "YYYY-MM-DD" key. */
    function nextDayKey(key) {
        var p = root.dayParts(key);
        var d = new Date(p.y, p.m, p.d + 1);
        return root.dayKey({ y: d.getFullYear(), m: d.getMonth(), d: d.getDate() });
    }

    /**
     * The next recurrence day of a monthly/yearly event strictly after refMs:
     * the period's day { y, m, d } (a Feb 29 monthly/yearly entry rolls to the
     * next real day when its day does not exist, mirroring the grid's display).
     */
    function periodDay(e, refMs) {
        var p = root.dayParts(e.date);
        if (e.recur === "year") {
            var y = p.y;
            while (root.stampAt("0:00", y, p.m, p.d) <= refMs)
                y += 1;
            return { y: y, m: p.m, d: p.d };
        }
        var now = new Date(refMs);
        if (root.stampAt("0:00", now.getFullYear(), now.getMonth(), p.d) <= refMs)
            return { y: now.getFullYear(), m: now.getMonth() + 1, d: p.d };
        return { y: now.getFullYear(), m: now.getMonth(), d: p.d };
    }

    /**
     * All reminder instants of e for its next period (or whole one-off span),
     * each strictly after refMs as { kind, at }. start/end for timed events,
     * allday for an all-day event's next covered day.
     */
    function nextInstants(e, refMs) {
        if (e.time && e.time.length > 0) {
            if (e.recur === "") {
                var start = root.dayParts(e.date);
                var last = e.endDate && e.endDate.length > 0
                    ? root.dayParts(e.endDate) : start;
                var inst = [];
                var ats = root.stampAt(e.time, start.y, start.m, start.d);
                if (ats > refMs)
                    inst.push({ kind: "start", at: ats });
                if (e.endTime && e.endTime.length > 0) {
                    var ate = root.stampAt(e.endTime, last.y, last.m, last.d);
                    if (ate > refMs)
                        inst.push({ kind: "end", at: ate });
                }
                return inst;
            }
            var day = root.containingDay(e, refMs);
            var out = [];
            var a = root.stampAt(e.time, day.y, day.m, day.d);
            if (a > refMs)
                out.push({ kind: "start", at: a });
            if (e.endTime && e.endTime.length > 0) {
                var b = root.stampAt(e.endTime, day.y, day.m, day.d);
                if (b > refMs)
                    out.push({ kind: "end", at: b });
            }
            if (out.length > 0)
                return out;
            // The period containing refMs is fully past (or its instants have
            // already gone): move to the next period.
            var day2 = root.periodDay(e, refMs);
            var out2 = [];
            var a2 = root.stampAt(e.time, day2.y, day2.m, day2.d);
            if (a2 > refMs)
                out2.push({ kind: "start", at: a2 });
            if (e.endTime && e.endTime.length > 0) {
                var b2 = root.stampAt(e.endTime, day2.y, day2.m, day2.d);
                if (b2 > refMs)
                    out2.push({ kind: "end", at: b2 });
            }
            return out2;
        }

        // All-day: recurring fires its single period day; a one-off span fires
        // every covered day at allDayReminderTime.
        if (e.recur !== "") {
            var d1 = root.periodDay(e, refMs);
            var at1 = root.stampAt(root.allDayReminderTime, d1.y, d1.m, d1.d);
            return at1 > refMs ? [{ kind: "allday", at: at1 }] : [];
        }
        var startKey = e.date;
        var endKey = root.lastDay(e);
        var now = new Date(refMs);
        var todayKey = root.dayKey({
            y: now.getFullYear(), m: now.getMonth(), d: now.getDate()
        });
        var cand, todayAt;
        if (todayKey < startKey) {
            cand = startKey;
        } else if (todayKey <= endKey) {
            todayAt = root.stampAt(root.allDayReminderTime,
                now.getFullYear(), now.getMonth(), now.getDate());
            cand = todayAt > refMs ? todayKey : root.nextDayKey(todayKey);
            if (cand > endKey)
                return [];
        } else {
            return [];
        }
        var p2 = root.dayParts(cand);
        var at2 = root.stampAt(root.allDayReminderTime, p2.y, p2.m, p2.d);
        return at2 > refMs ? [{ kind: "allday", at: at2 }] : [];
    }

    /**
     * The { y, m, d } period day of a recurring event that contains refMs (for
     * match-on-fire), so the armed instant is found even when the arming scan
     * has already moved past the period's midnight (e.g. a monthly event armed
     * at its 16:00 — the day's 00:00 has passed by the time we re-scan).
     */
    function containingDay(e, refMs) {
        var p = root.dayParts(e.date);
        if (e.recur === "year")
            return { y: new Date(refMs).getFullYear(), m: p.m, d: p.d };
        var now = new Date(refMs);
        return { y: now.getFullYear(), m: now.getMonth(), d: p.d };
    }

    /**
     * All reminder instants of e in the single period containing refMs { kind,
     * at }, regardless of whether they sit before or after refMs. Used by the
     * fire match to recognise the event(s) that landed on the armed instant.
     */
    function containingInstants(e, refMs) {
        if (e.time && e.time.length > 0) {
            if (e.recur === "") {
                var start = root.dayParts(e.date);
                var last = e.endDate && e.endDate.length > 0
                    ? root.dayParts(e.endDate) : start;
                var out = [{ kind: "start",
                             at: root.stampAt(e.time, start.y, start.m, start.d) }];
                if (e.endTime && e.endTime.length > 0)
                    out.push({ kind: "end",
                               at: root.stampAt(e.endTime, last.y, last.m, last.d) });
                return out;
            }
            var day = root.containingDay(e, refMs);
            var list = [];
            list.push({ kind: "start",
                        at: root.stampAt(e.time, day.y, day.m, day.d) });
            if (e.endTime && e.endTime.length > 0)
                list.push({ kind: "end",
                            at: root.stampAt(e.endTime, day.y, day.m, day.d) });
            return list;
        }
        if (e.recur !== "") {
            var d1 = root.containingDay(e, refMs);
            return [{ kind: "allday",
                      at: root.stampAt(root.allDayReminderTime, d1.y, d1.m, d1.d) }];
        }
        // One-off all-day span: the covered day containing refMs, if any.
        var now = new Date(refMs);
        var todayKey = root.dayKey({
            y: now.getFullYear(), m: now.getMonth(), d: now.getDate()
        });
        if (todayKey >= e.date && todayKey <= root.lastDay(e)) {
            var p = root.dayParts(todayKey);
            return [{ kind: "allday",
                      at: root.stampAt(root.allDayReminderTime, p.y, p.m, p.d) }];
        }
        return [];
    }

    /** Announce an event whose time has come. */
    function notify(e, kind) {
        var body = kind === "start" ? "Starts · " + (e.time || "")
            : kind === "end" ? "Ends · " + (e.endTime || "")
            : "All day";
        remProc.command = ["notify-send", "-a", "Ukishima",
                           e.text || "Event", body];
        remProc.running = true;
    }

    /**
     * Point the one-shot timer at the soonest reminder instant; stop it when
     * none is left. A wake beyond the timer's ceiling arms at the ceiling and
     * re-arms on that early wake — still a single OS timer, still no polling.
     */
    function armReminder() {
        var now = Date.now();
        var soon = null;
        for (var i = 0; i < root.events.length; i++) {
            var list = root.nextInstants(root.events[i], now);
            for (var j = 0; j < list.length; j++) {
                if (soon === null || list[j].at < soon.at)
                    soon = list[j];
            }
        }
        if (soon === null) {
            remTimer.stop();
            root.armedFor = null;
            return;
        }
        root.armedFor = soon;
        var delay = soon.at - now;
        remTimer.cappedWake = delay > root.maxTimerMs;
        remTimer.interval = remTimer.cappedWake ? root.maxTimerMs : delay;
        remTimer.start();
    }

    Timer {
        id: remTimer
        repeat: false
        property bool cappedWake: false

        onTriggered: {
            var t = root.armedFor;
            if (!remTimer.cappedWake && t) {
                for (var i = 0; i < root.events.length; i++) {
                    var e = root.events[i];
                    var list = root.containingInstants(e, t.at);
                    for (var j = 0; j < list.length; j++)
                        if (list[j].at === t.at)
                            root.notify(e, list[j].kind);
                }
            }
            root.armReminder();
        }
    }

    Process {
        id: remProc
    }

    Component.onCompleted: {
        reloadEvents();
        root.armReminder();
    }

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: true
        printErrors: false

        onLoadFailed: function (error) {
            if (error === FileViewError.FileNotFound)
                file.setText("[]");
        }
    }
}
