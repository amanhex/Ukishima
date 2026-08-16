pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Compact keyboard-layout code for the collapsed pill. Seeds once from
 * `hyprctl devices -j` — the event socket only reports changes, never the
 * current value — then follows `activelayout` events after that. Prefers the
 * XKB short code from the device (`layout`, e.g. "us" → US); when several
 * layouts are configured that field is comma-joined, so it falls back to the
 * active keymap's human name ("English (US)") folded into a short code.
 * `event.parse(n)` splits the comma-separated payload once, so layouts whose
 * own names contain commas ("English (US, intl.)") stay intact.
 */
Item {
    id: root

    property string code: "US"

    function shortCode(full) {
        var f = String(full || "").toLowerCase();
        var map = {
            "rus": "RU", "ukr": "UA", "bel": "BY", "kaz": "KZ",
            "german": "DE", "deutsch": "DE", "deu": "DE",
            "french": "FR", "fra": "FR",
            "spanish": "ES", "spa": "ES",
            "italian": "IT", "ita": "IT",
            "portugu": "PT", "por": "PT",
            "polish": "PL", "pol": "PL",
            "turkish": "TR", "tur": "TR",
            "arabic": "AR", "ara": "AR",
            "hebrew": "HE", "heb": "HE",
            "japanese": "JA", "jpn": "JA",
            "korean": "KO", "kor": "KO",
            "chinese": "ZH", "chi": "ZH",
            "hindi": "IN", "indian": "IN", "devanagari": "IN",
            "english": "US", "eng": "US", "us": "US",
            "british": "UK", "uk": "UK",
            "dvorak": "US", "colemak": "US"
        };
        for (var key in map) {
            if (f.indexOf(key) >= 0)
                return map[key];
        }
        var m = String(full || "").match(/[A-Za-z]{2,}/);
        return m ? m[0].slice(0, 2).toUpperCase() : "US";
    }

    Process {
        id: seedProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text);
                    var kbs = d.keyboards || [];
                    var chosen = null;
                    for (var i = 0; i < kbs.length; i++) {
                        var kb = kbs[i];
                        if (!kb.layout && !kb.active_keymap)
                            continue;
                        if (!chosen)
                            chosen = kb;
                        if (kb.main) {
                            chosen = kb;
                            break;
                        }
                    }
                    if (chosen) {
                        if (chosen.layout && chosen.layout.indexOf(",") < 0)
                            root.code = chosen.layout.slice(0, 2).toUpperCase();
                        else if (chosen.active_keymap)
                            root.code = root.shortCode(chosen.active_keymap);
                    }
                } catch (e) { }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            var parts = event.parse(2);
            if (parts.length === 2)
                root.code = root.shortCode(parts[1]);
        }
    }

    Component.onCompleted: seedProc.running = true
}
