// SPDX-License-Identifier: 0BSD
// Original compound-glyph drawing rules from the editorial and print studies.
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));

const lerp = (a, b, t) => a + (b - a) * t;

const smooth = v => {
    const t = clamp(v);

    return t * t * (3 - 2 * t);
};

function hash(x, y, seed = 0) {
    let n = Math.imul(x + 1, 374761393) ^ Math.imul(y + 1, 668265263) ^ Math.imul(seed + 1, 1442695041);
    n = Math.imul(n ^ (n >>> 13), 1274126177);

    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
}

function glyphColour(t, emphasis) {
    t = clamp(t * emphasis / 100);
    const a = [104, 102, 94], b = [209, 22, 28];

    return `rgb(${a.map((v, i) => Math.round(lerp(v, b[i], t))).join(',')})`;
}

function glyphMarks(p, emphasis) {
    const marks = [];
    const path = (points, c = '#68665e', w = 1, alpha = 1) => marks.push({ type: 'path', points, c, w, alpha });
    const transform = (points, cx, cy, angle) => points.map(([x, y]) => [cx + x * Math.cos(angle) - y * Math.sin(angle), cy + x * Math.sin(angle) + y * Math.cos(angle)]);

    function glyph(cx, cy, size, key, depth, alpha) {
        if (alpha < .004) return;

        const a = Math.floor(hash(key, depth, 27) * 4) * Math.PI / 2;
        const bend = (hash(key, depth, 17) - .5) * .26;
        const local = Math.sin(p * .24 + key) * .075;
        const strokes = [
            [[-.35, -.4], [-.35, .34], [-.14, .34]],
            [[-.35, -.13], [.31, -.13], [.31, .12]],
            [[.02 + bend, -.39], [.02 + bend, .34]],
            [[-.12, .12 + local], [.35, .12 + local], [.35, .39]],
            [[-.4, -.39], [-.2, -.39]],
            [[.22, -.4], [.4, -.4], [.4, -.25]]
        ];
        const tint = smooth((p * .012 + .23 - hash(key, depth, 61)) / .2);
        strokes.forEach(points => path(transform(points.map(([x, y]) => [x * size, y * size]), cx, cy, a), glyphColour(tint, emphasis), Math.max(.75, size * .031), alpha));
    }

    function branch(cx, cy, size, key, depth, threshold, alpha) {
        const split = depth < 3 ? smooth((p - threshold) / 2.2) : 0;
        glyph(cx, cy, size, key, depth, alpha * (1 - split));

        if (split > 0)
            for (let child = 0; child < 4; child++) {
                const childKey = key * 5 + child + 1;
                const x = cx + (child % 2 ? 1 : -1) * size * .25 * split;
                const y = cy + (child < 2 ? -1 : 1) * size * .25 * split;
                const next = depth === 0 ? -2 + hash(childKey, depth, 7) * 25 : threshold + 6 + hash(childKey, depth, 7) * 16;
                branch(x, y, size * .5, childKey, depth + 1, next, alpha * split);
            }
    }

    for (let y = 0; y < 3; y++)
        for (let x = 0; x < 3; x++)
            branch(48 + x * 78, 48 + y * 78, 78, y * 3 + x + 1, 0, -4, 1);

    return marks;
}
