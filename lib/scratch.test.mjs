import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { locate, noteAt, open, remove } = require("./scratch.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log(`PASS ${msg}`);
    else { console.log(`FAIL ${msg}: got ${a}, want ${e}`); failed++; }
}

const notes = [{ slug: "a" }, { slug: "b" }, { slug: "c" }];
const host = {
    calls: [],
    openNote(slug) { this.calls.push(["note", slug]); },
    openCreate() { this.calls.push(["create"]); },
};
const scratch = { removed: [], remove(slug) { this.removed.push(slug); } };

eq(locate(notes, "b", 0), 1, "locate follows the current slug");
eq(locate(notes, "gone", 1), 1, "locate keeps an in-range cursor when the slug is gone");
eq(locate(notes, "gone", 9), 2, "locate clamps an out-of-range cursor");
eq(locate([], "gone", 0), 0, "locate clamps to 0 on an empty list");
eq(noteAt(notes, 2)?.slug, "c", "noteAt returns the cursor's note");
eq(noteAt(notes, 7), null, "noteAt returns null off the end");

eq(open(host, notes, 1) || host.calls.pop(), ["note", "b"], "open opens the cursor's note");
eq(open(host, notes, 9) || host.calls.pop(), ["create"], "open creates when the cursor is empty");

remove(scratch, notes, 0);
remove(scratch, notes, 9);
eq(scratch.removed, ["a"], "remove deletes only the cursor's note");

if (failed) { console.log(`${failed} failed`); process.exit(1); }
console.log("all passed");
