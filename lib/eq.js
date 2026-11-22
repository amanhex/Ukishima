// EQ math and AutoEQ parsing, kept out of QML so the branchy parts have a node
// test next to them. A sign flip in the biquad still produces sound that "works"
// — it just sounds wrong — so the coefficients are checked away from the ear.

/** Ten band centres, in Hz, matching the filter-chain graph in sound/eq.conf. */
var FREQS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

/**
 * RBJ biquad for one AutoEQ filter at the profile's fixed 48 kHz rate, with the
 * coefficients normalised to a0 = 1. Returns [b0, b1, b2, a0, a1, a2].
 */
function biquad(f) {
    var A = Math.pow(10, f.g / 40);
    var w = 2 * Math.PI * f.f / 48000;
    var c = Math.cos(w);
    var al = Math.sin(w) / (2 * f.q);
    var sq = 2 * Math.sqrt(A) * al;
    var k;
    if (f.t === "LSC")
        k = [A * ((A + 1) - (A - 1) * c + sq), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sq),
             (A + 1) + (A - 1) * c + sq, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sq];
    else if (f.t === "HSC")
        k = [A * ((A + 1) + (A - 1) * c + sq), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sq),
             (A + 1) - (A - 1) * c + sq, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sq];
    else
        k = [1 + al * A, -2 * c, 1 - al * A, 1 + al / A, -2 * c, 1 - al / A];
    return [k[0] / k[3], k[1] / k[3], k[2] / k[3], 1, k[4] / k[3], k[5] / k[3]];
}

/** Parse AutoEQ's results/INDEX.md into `{ name, path, by }` entries. */
function parseIndex(text) {
    var out = [];
    var lines = (text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = /^- \[(.*)\]\((\.\/.*)\) by (.*)$/.exec(lines[i]);
        if (m)
            out.push({ name: m[1], path: m[2], by: m[3].replace(/ on .*/, "") });
    }
    return out;
}

/** Parse one ParametricEQ.txt into `{ preamp, filters }`, or null when it has none. */
function parseProfile(text) {
    var filters = [];
    var preamp = 0;
    var lines = (text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var pre = /^Preamp:\s*([-\d.]+)/.exec(lines[i]);
        if (pre)
            preamp = Number(pre[1]);
        var m = /Filter \d+: ON (PK|LSC|HSC) Fc ([\d.]+) Hz Gain ([-\d.]+) dB Q ([\d.]+)/.exec(lines[i]);
        if (m && filters.length < 10)
            filters.push({ t: m[1], f: Number(m[2]), g: Number(m[3]), q: Number(m[4]) });
    }
    return filters.length ? { preamp: preamp, filters: filters } : null;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { FREQS: FREQS, biquad: biquad, parseIndex: parseIndex, parseProfile: parseProfile };
