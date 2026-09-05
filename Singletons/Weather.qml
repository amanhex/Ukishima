pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live weather for the pill's hover glance, served by Open-Meteo with no API key.
 * Location resolves once and is cached so a restart never re-hits the network for
 * coordinates: by default the city, latitude and longitude come from a keyless IP
 * lookup (ip-api), but a non-empty `Flags.weatherCity` override geocodes that name
 * via Open-Meteo's geocoder instead. Once coordinates are known the forecast runs
 * immediately and then every 20 minutes, exposing the current conditions plus a
 * 24-hour hourly strip.
 *
 * Everything is async through `Process` + `curl`, mirroring how Sysmon and Devices
 * fetch, so startup never blocks on a slow or absent connection. Every JSON parse
 * is guarded: a partial body or network blip leaves the last good values in place.
 * The last successful forecast is also cached to disk, so the instant the deferred
 * singleton arms on first hover the glance renders instantly from cache and the
 * fresh fetch lands ~1 second later in the background.
 *
 * Conditions render as on-brand kanji rather than icons — 晴 clear, 曇 cloud,
 * 雨 rain, 雪 snow, 霧 fog, 雷 thunder, 月 a clear night — keyed off the WMO weather
 * code via `glyphFor`, with `labelFor` giving the short english word.
 */
Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/pill"

    property int tempNow: 0
    property int codeNow: 0
    property int humidity: 0
    property bool isDay: true
    property string city: ""
    property var hourly: []
    property var daily: []
    property bool ready: false

    property real lat: 0
    property real lon: 0
    property bool located: false

    /**
     * Set the first time any weather UI is demanded (pill expands / a surface
     * opens). Until then nothing touches the network: the chip renders from the
     * disk cache, and the 20-minute refresh stays silent. This keeps the
     * always-built chip layout-stable and instant from the first frame.
     */
    property bool needed: false

    /**
     * Maps a WMO weather code to its on-brand kanji. Clear skies show 月 at night
     * so the glance reads day-versus-night at a glance; every other condition is
     * the same glyph round the clock.
     */
    function glyphFor(code, day) {
        if (code === 0)
            return day ? "sun" : "moon";
        if (code <= 3)
            return "cloud";
        if (code === 45 || code === 48)
            return "cloud-fog";
        if (code >= 95)
            return "cloud-lightning";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "cloud-snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "cloud-rain";
        return "cloud";
    }

    /** Short english word for a WMO weather code, for labels and accessibility. */
    function labelFor(code) {
        if (code === 0)
            return "Clear";
        if (code <= 3)
            return "Cloudy";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 95)
            return "Thunder";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "Snow";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "Rain";
        return "Cloudy";
    }

    /** Persist resolved coordinates so a restart skips the location round-trip. */
    function writeLoc() {
        locCache.setText(JSON.stringify({ city: root.city, lat: root.lat, lon: root.lon }));
    }

    /**
     * Persists the last good forecast so a fresh session shows conditions instantly
     * instead of a blank chip while the first fetch runs.
     */
    function writeWeather() {
        weatherCache.setText(JSON.stringify({
            tempNow: root.tempNow,
            codeNow: root.codeNow,
            humidity: root.humidity,
            isDay: root.isDay,
            ts: Date.now()
        }));
    }

    /**
     * Applies the cached forecast synchronously (blockLoading) at instantiation.
     * No network is touched; the in-flight fetch overwrites these within ~1 s.
     */
    function loadWeatherCache() {
        try {
            var c = JSON.parse(weatherCache.text());
            if (c && typeof c.codeNow === "number") {
                root.tempNow = c.tempNow || 0;
                root.codeNow = c.codeNow;
                root.humidity = c.humidity || 0;
                root.isDay = c.isDay !== false;
                root.ready = true;
            }
        } catch (e) {}
    }

    function fetchWeather() {
        if (!root.needed || !located || wxProc.running)
            return;
        wxProc.running = true;
    }

    /** First weather demand arms the network path (loads fresh data on hover). */
    onNeededChanged: {
        if (root.needed) {
            if (root.located)
                root.fetchWeather();
            else
                root.locate();
        }
    }

    /**
     * Loads cached coordinates synchronously (blockLoading) but defers location
     * lookup and the forecast fetch until `needed` (first hover / surface open).
     * The cached forecast already made `ready` true, so the arm shows instantly.
     */
    Component.onCompleted: {
        root.loadWeatherCache();
        try {
            var c = JSON.parse(locCache.text());
            if (c && typeof c.lat === "number" && typeof c.lon === "number") {
                root.city = c.city || "";
                root.lat = c.lat;
                root.lon = c.lon;
                root.located = true;
            }
        } catch (e) {}
    }

    FileView {
        id: locCache
        path: root.cacheDir + "/weather-loc.json"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: weatherCache
        path: root.cacheDir + "/weather-cache.json"
        blockLoading: true
        printErrors: false
    }

    /** Resolve coordinates: geocode the manual city override, else fall back to IP. */
    function locate() {
        if (!root.needed)
            return;
        if (Flags.weatherCity && Flags.weatherCity.trim().length > 0)
            geoProc.running = true;
        else
            ipProc.running = true;
    }

    Connections {
        target: Flags
        function onWeatherCityChanged() { root.locate(); }
    }

    Process {
        id: ipProc
        command: ["curl", "-s", "--max-time", "8", "http://ip-api.com/json?fields=lat,lon,city"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    if (typeof d.lat === "number" && typeof d.lon === "number") {
                        root.city = d.city || "";
                        root.lat = d.lat;
                        root.lon = d.lon;
                        root.located = true;
                        root.writeLoc();
                        root.fetchWeather();
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "8", "-G",
            "https://geocoding-api.open-meteo.com/v1/search",
            "--data-urlencode", "name=" + (Flags.weatherCity || ""),
            "--data-urlencode", "count=1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    var r = d.results && d.results[0];
                    if (r && typeof r.latitude === "number" && typeof r.longitude === "number") {
                        root.city = r.name || "";
                        root.lat = r.latitude;
                        root.lon = r.longitude;
                        root.located = true;
                        root.writeLoc();
                        root.fetchWeather();
                    } else {
                        root.ipProc.running = true;
                    }
                } catch (e) { root.ipProc.running = true; }
            }
        }
    }

    Process {
        id: wxProc
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat
            + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m"
            + "&hourly=temperature_2m,weather_code&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,relative_humidity_2m_mean&forecast_days=5&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    var cur = d.current;
                    if (!cur)
                        return;
                    var rows = [];
                    var h = d.hourly;
                    if (h && h.time && h.temperature_2m && h.weather_code) {
                        var n = Math.min(h.time.length, h.temperature_2m.length, h.weather_code.length);
                        for (var i = 0; i < n; i++) {
                            rows.push({
                                hour: h.time[i].slice(11, 13),
                                temp: Math.round(h.temperature_2m[i]),
                                code: h.weather_code[i]
                            });
                        }
                    }
                    var days = [];
                    var dd = d.daily;
                    if (dd && dd.time && dd.weather_code && dd.temperature_2m_max && dd.relative_humidity_2m_mean) {
                        var dn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                        var m = Math.min(dd.time.length, dd.weather_code.length, dd.temperature_2m_max.length, dd.relative_humidity_2m_mean.length);
                        for (var j = 0; j < m; j++) {
                            days.push({
                                day: dn[new Date(dd.time[j]).getDay()],
                                code: dd.weather_code[j],
                                temp: Math.round(dd.temperature_2m_max[j]),
                                rh: Math.round(dd.relative_humidity_2m_mean[j])
                            });
                        }
                    }
                    root.tempNow = Math.round(cur.temperature_2m);
                    root.codeNow = cur.weather_code;
                    root.humidity = Math.round(cur.relative_humidity_2m);
                    root.isDay = cur.is_day === 1;
                    root.hourly = rows;
                    root.daily = days;
                    root.ready = true;
                    root.writeWeather();
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1200000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
