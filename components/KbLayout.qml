pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Compact keyboard-layout code for the collapsed pill.
 * Seeds once from `hyprctl devices -j` (Hyprland‑specific). On other
 * compositors the command will fail silently and the pill keeps the default
 * "US" code. The pill shows the layout chip only when
 * `Wm.caps.keyboardLayout` is true.
 *
 * To add support for another compositor:
 *   1. Set `keyboardLayout: true` in that compositor's Wm singleton caps.
 *   2. Extend the `seedProc` command or add a new source that reads the layout
 *      from that compositor's equivalent of `hyprctl devices -j`.
 *   3. If the compositor exposes layout via an environment variable or IPC
 *      event, add a listener here.
 */
Item {
    id: root

    property string code: "US"
    /** Show the layout chip only when the compositor declares it. */
    property bool active: Wm.caps.keyboardLayout

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
                } catch (e) {
                    // non‑JSON or command not available (e.g. niri) → keep "US"
                }
            }
        }
    }

    Component.onCompleted: if (root.active) seedProc.running = true
}