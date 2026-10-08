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

if (typeof module !== "undefined" && module.exports) {
    module.exports = { visibleApps, byId };
}
