import { createRequire } from "node:module";
const require = createRequire(import.meta.url);

// lerpColor reaches for the QML `Qt` global; node has none, so stand in for the
// one call it makes and return the channels as a plain object to compare.
globalThis.Qt = {
    rgba: (r, g, b, a) => ({ r, g, b, a }),
};

const { lerpColor, stepPercent, stepIndex } = require("./util.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        console.log(`PASS ${msg}`);
    } else {
        console.log(`FAIL ${msg}: got ${a}, want ${e}`);
        failed++;
    }
}

const black = { r: 0, g: 0, b: 0 };
const white = { r: 1, g: 1, b: 1 };

eq(lerpColor(black, white, 0), { r: 0, g: 0, b: 0, a: 1 }, "lerpColor leaves a at t=0");
eq(lerpColor(black, white, 1), { r: 1, g: 1, b: 1, a: 1 }, "lerpColor reaches b at t=1");
eq(lerpColor(black, white, 0.5), { r: 0.5, g: 0.5, b: 0.5, a: 1 }, "lerpColor blends midway");
eq(lerpColor({ r: 0.2, g: 0.4, b: 0.6, a: 0.3 }, black, 0).a, 1,
   "lerpColor forces alpha to 1");

eq(stepPercent(0.5, 5), 0.55, "stepPercent nudges up");
eq(stepPercent(0.5, -5), 0.45, "stepPercent nudges down");
eq(stepPercent(0.98, 5), 1, "stepPercent clamps at 1");
eq(stepPercent(0.02, -5), 0, "stepPercent clamps at 0");

eq(stepIndex(5, 2, 1), 3, "stepIndex moves forward");
eq(stepIndex(5, 4, 1), 4, "stepIndex clamps at the last index");
eq(stepIndex(5, 0, -1), 0, "stepIndex clamps at 0");
eq(stepIndex(1, 0, 1), 0, "stepIndex keeps a single-item list at 0");

if (failed) {
    console.log(`${failed} failed`);
    process.exit(1);
}
console.log("all passed");
