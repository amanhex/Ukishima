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

// Both user stops Off: the walk is the two fixed stops, pill -> media -> timer -> pill.
const plain = surfaces(["", ""]);
eq(plain, ["media", "timer"], "empty slots leave the two fixed stops");
eq(next(plain, ""), "media", "from the rest, right-click opens media");
eq(next(plain, "media"), "timer", "media -> timer");
eq(next(plain, "timer"), "", "timer wraps back to the resting pill");

// Configured stops append after the fixed ones, in order.
const full = surfaces(["calendar", "mixer"]);
eq(full, ["media", "timer", "calendar", "mixer"], "user stops append after the fixed ones");
eq(next(full, ""), "media", "rest -> media");
eq(next(full, "media"), "timer", "media -> timer");
eq(next(full, "timer"), "calendar", "timer -> 4th");
eq(next(full, "calendar"), "mixer", "4th -> 5th");
eq(next(full, "mixer"), "", "5th wraps back to the resting pill");

// A blank in the middle is skipped, so a gap never eats a right-click.
eq(next(surfaces(["calendar", ""]), "timer"), "calendar", "4th set, 5th Off");
eq(next(surfaces(["", "mixer"]), "timer"), "mixer", "5th set, 4th Off");

// Repeats collapse, including a slot repeating a fixed stop.
eq(surfaces(["mixer", "mixer"]), ["media", "timer", "mixer"], "duplicate user stops collapse");
eq(surfaces(["media", "timer"]), ["media", "timer"], "fixed stops cannot be duplicated into the walk");

// Something opened outside the walk restarts it rather than advancing blindly.
eq(next(full, "wallpaper"), "media", "an off-cycle surface restarts at media");

if (failed) {
    console.log(`${failed} failed`);
    process.exit(1);
}
console.log("all passed");
