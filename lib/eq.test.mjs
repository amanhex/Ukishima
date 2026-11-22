import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { FREQS, biquad, parseIndex, parseProfile } = require("./eq.js");

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
function near(actual, expected, msg) {
    if (Math.abs(actual - expected) < 1e-9) {
        console.log(`PASS ${msg}`);
    } else {
        console.log(`FAIL ${msg}: got ${actual}, want ${expected}`);
        failed++;
    }
}

eq(FREQS, [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000], "ten band centres");

for (const type of ["PK", "LSC", "HSC"]) {
    const flat = biquad({ t: type, f: 1000, g: 0, q: 1 });
    near(flat[0], flat[3], `${type} flat gain keeps b0 = a0`);
    near(flat[1], flat[4], `${type} flat gain keeps b1 = a1`);
    near(flat[2], flat[5], `${type} flat gain keeps b2 = a2`);
}

const boost = biquad({ t: "PK", f: 1000, g: 6, q: 1 });
const cut = biquad({ t: "PK", f: 1000, g: -6, q: 1 });
if (boost[0] / boost[3] > 1 && cut[0] / cut[3] < 1)
    console.log("PASS PK gain moves the numerator the right way");
else {
    console.log("FAIL PK gain moves the numerator the right way");
    failed++;
}

const index = parseIndex([
    "- [Sennheiser HD 600](./oratory1990/over-ear/Sennheiser%20HD%20600) by oratory1990",
    "- [1Custom SA02](./crinacle/711%20in-ear/1Custom%20SA02) by crinacle on 711",
    "noise",
].join("\n"));
eq(index, [
    { name: "Sennheiser HD 600", path: "./oratory1990/over-ear/Sennheiser%20HD%20600", by: "oratory1990" },
    { name: "1Custom SA02", path: "./crinacle/711%20in-ear/1Custom%20SA02", by: "crinacle" },
], "AutoEQ index entries");

const profile = parseProfile([
    "Preamp: -6.3 dB",
    "Filter 1: ON LSC Fc 105 Hz Gain 6.5 dB Q 0.70",
    "Filter 2: ON PK Fc 125 Hz Gain -2.7 dB Q 0.55",
    "Filter 3: ON HSC Fc 10000 Hz Gain -3.1 dB Q 0.70",
    "Filter 4: ON PK Fc 522 Hz Gain 0.7 dB Q 1.02",
].join("\n"));
eq(profile.preamp, -6.3, "AutoEQ profile preamp");
eq(profile.filters, [
    { t: "LSC", f: 105, g: 6.5, q: 0.7 },
    { t: "PK", f: 125, g: -2.7, q: 0.55 },
    { t: "HSC", f: 10000, g: -3.1, q: 0.7 },
    { t: "PK", f: 522, g: 0.7, q: 1.02 },
], "AutoEQ profile filters");
eq(parseProfile("Preamp: -2 dB\nnothing here"), null, "profile without filters is rejected");

if (failed > 0) {
    console.log(`\n${failed} failed`);
    process.exit(1);
}
