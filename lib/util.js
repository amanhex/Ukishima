// Small pure helpers shared by surfaces and chrome.

/**
 * Linear blend from `a` toward `b`, alpha forced to 1 — the caller's own
 * opacity does the rest. Every copy of this used to live on a surface, so a
 * tint fix had to be made once per surface.
 */
function lerpColor(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t,
                   a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, 1);
}

/** A fader nudge: `value` moved by `deltaPct` percent, clamped to 0..1. */
function stepPercent(value, deltaPct) {
    return Math.max(0, Math.min(1, value + deltaPct / 100));
}

/**
 * The next index in a list of `count`, clamped so it never leaves 0..count-1.
 * Callers skip the empty-list case themselves, as they always have.
 */
function stepIndex(count, index, delta) {
    return Math.max(0, Math.min(count - 1, index + delta));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { lerpColor, stepPercent, stepIndex };
}
