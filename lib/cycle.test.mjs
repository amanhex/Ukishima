import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { surfaces, next } = require("./cycle.js");

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

// No slots configured: right-click stays the rest <-> media toggle it shipped as.
const plain = surfaces(["", "", ""]);
eq(plain, ["media"], "empty slots leave the media stop alone");
eq(next(plain, ""), "media", "from the rest, right-click opens media");
eq(next(plain, "media"), "", "from media with no slots, right-click returns to the rest");

// Configured slots append after media, in order.
const full = surfaces(["calendar", "mixer", "sysmon"]);
eq(full, ["media", "calendar", "mixer", "sysmon"], "slots append after the fixed media stop");
eq(next(full, ""), "media", "rest -> media");
eq(next(full, "media"), "calendar", "media -> 3rd");
eq(next(full, "calendar"), "mixer", "3rd -> 4th");
eq(next(full, "mixer"), "sysmon", "4th -> 5th");
eq(next(full, "sysmon"), "", "5th wraps back to the resting pill");

// A blank in the middle is skipped, so a gap never eats a right-click.
eq(next(surfaces(["calendar", "", "sysmon"]), "calendar"), "sysmon", "blank slots are skipped");

// Repeats collapse, including a slot repeating the fixed media stop.
eq(surfaces(["mixer", "mixer", "media"]), ["media", "mixer"], "duplicates collapse");

// Something opened outside the cycle restarts it rather than advancing blindly.
eq(next(full, "wallpaper"), "media", "an off-cycle surface restarts at media");

if (failed) {
    console.log(`${failed} failed`);
    process.exit(1);
}
console.log("all passed");
