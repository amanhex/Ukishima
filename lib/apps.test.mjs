import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { visibleApps, byId } = require("./apps.js");

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

const apps = [
    { id: "alpha.desktop", icon: "alpha" },
    { id: "Beta.Desktop", noDisplay: true },
    { id: "iconless.desktop" },
    null,
];

// visibleApps is the launcher's and the dock's shared source of truth.
eq(visibleApps(apps).map(e => e.id), ["alpha.desktop", "iconless.desktop"],
   "visibleApps drops noDisplay entries and nulls");
eq(visibleApps([]), [], "visibleApps handles an empty list");

// byId must NOT apply the noDisplay filter: a persisted pin resolves against
// every installed entry, hidden or not.
eq(byId(apps, "alpha.desktop")?.id, "alpha.desktop", "byId exact match");
eq(byId(apps, "ALPHA.DESKTOP")?.id, "alpha.desktop", "byId is case-insensitive");
eq(byId(apps, "beta.desktop")?.id, "Beta.Desktop", "byId matches hidden entries too");
eq(byId(apps, "iconless.desktop")?.id, "iconless.desktop", "byId keeps iconless entries by default");
eq(byId(apps, "iconless.desktop", true), null, "needIcon skips entries carrying no icon");
eq(byId(apps, "alpha.desktop", true)?.id, "alpha.desktop", "needIcon still returns iconed entries");
eq(byId(apps, "missing.desktop"), null, "byId returns null when nothing matches");
eq(byId(apps, ""), null, "byId rejects an empty id");
eq(byId(apps, null), null, "byId rejects a null id");

if (failed) {
    console.log(`${failed} failed`);
    process.exit(1);
}
console.log("all passed");
