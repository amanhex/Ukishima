// The bar's right-click walk. Plain functions next to their node test because
// the order and the wrap-around are the only branchy part of the feature, and
// reading them off a QML binding is how the wrap ends up off by one.

/**
 * The walk as surface names: the two fixed stops, `media` then `timer`, then
 * the user's stops 4 and 5 in order, blanks dropped and repeats ignored. The
 * resting pill is stop 1 and never appears here — it is the empty string the
 * wrap returns, and a walk of just the two fixed stops is what right-click does
 * with both user stops Off.
 */
function surfaces(slots) {
    var out = ["media", "timer"];
    for (var i = 0; i < slots.length; i++) {
        var name = slots[i];
        if (name && out.indexOf(name) < 0)
            out.push(name);
    }
    return out;
}

/**
 * The stop after `cur`, or "" for the resting pill. A `cur` outside the list
 * (a surface opened by a chip, a keybind, or a hand-edited stale name)
 * restarts at media rather than guessing a position.
 */
function next(list, cur) {
    var i = list.indexOf(cur);
    if (i < 0)
        return list[0];
    return i + 1 < list.length ? list[i + 1] : "";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { surfaces: surfaces, next: next };
}
