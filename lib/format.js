// Shared number/string formatting used across surfaces.

function pad2(n) {
    return String(n).padStart(2, "0");
}

/** "m:ss" for a duration in seconds; 0 and below read as "0:00". */
function fmtDuration(sec) {
    if (!(sec > 0))
        return "0:00";
    var t = Math.floor(sec);
    return Math.floor(t / 60) + ":" + pad2(t % 60);
}

/** Battery percent for a BlueZ device, -1 when BlueZ has no reading. */
function batteryPct(d) {
    if (!d || d.battery === undefined || d.battery === null || d.battery <= 0)
        return -1;
    var b = d.battery;
    if (b <= 1)
        b = b * 100;
    return Math.round(b);
}