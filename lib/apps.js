/**
 * Desktop-entry lookups shared by the launcher, the dock, the minimised tray
 * and the players. Each walked `DesktopEntries` on its own, so the `noDisplay`
 * filter was copy-pasted twice and the exact-id match four times, and a fix to
 * either had to be found in every copy. The entries are passed in
 * rather than read here: a QML-imported JS file cannot reach QML types.
 */

/** Every installed, displayable entry — the one source for "what is installed". */
function visibleApps(entries) {
    var out = [];
    for (var i = 0; i < entries.length; i++)
        if (entries[i] && !entries[i].noDisplay) out.push(entries[i]);
    return out;
}

/**
 * Exact, case-insensitive `id` match, first hit wins. `needIcon` skips
 * entries carrying no icon, for the callers that only want one to draw.
 */
function byId(entries, id, needIcon) {
    if (!id) return null;
    var q = String(id).toLowerCase();
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e && e.id && e.id.toLowerCase() === q && (!needIcon || e.icon))
            return e;
    }
    return null;
}

/**
 * Like `byId`, but also accepts an id missing its `.desktop` suffix. Pins
 * persisted by older builds were written without it, and both dock pages need
 * the same tolerance.
 */
function byIdLoose(entries, id) {
    var e = byId(entries, id);
    if (e || !id) return e;
    var q = String(id).toLowerCase();
    return q.endsWith(".desktop") ? byId(entries, q.slice(0, -8)) : null;
}

/**
 * The pins the dock can actually draw, in dock order: unresolved pins (app
 * uninstalled) are dropped. This is the dock's real order, not the raw array.
 */
function resolvePins(entries, pins) {
    var out = [];
    for (var i = 0; i < pins.length; i++) {
        var e = byIdLoose(entries, pins[i]);
        if (e) out.push(e.id);
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { visibleApps, byId, byIdLoose, resolvePins };
}
