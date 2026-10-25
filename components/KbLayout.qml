
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

Item {
    id: root

    property string code: root.compositor === "niri"
        ? shortCode(Wm.keyboardLayoutName) : "?"
    property bool active: Wm.caps.keyboardLayout

    readonly property string compositor: Wm.compositor

    function shortCode(full) {
        var f = String(full || "").toLowerCase();

        if (f.includes("british") || f.includes("(uk)"))
            return "GB";

        var map = {
            "rus": "RU", "ukr": "UA", "bel": "BY",
            "german": "DE", "deutsch": "DE",
            "french": "FR",
            "spanish": "ES",
            "italian": "IT",
            "portugu": "PT",
            "polish": "PL",
            "turkish": "TR",
            "arabic": "AR",
            "hebrew": "HE",
            "japanese": "JA",
            "korean": "KO",
            "chinese": "ZH",
            "hindi": "IN",
            "english": "US"
        };

        for (var key in map) {
            if (f.includes(key))
                return map[key];
        }

        var match = f.match(/[a-z]{2,}/);
        return match ? match[0].slice(0, 2).toUpperCase() : "?";
    }

    Process {
        id: hyprProc

        running: root.active && root.compositor === "hyprland"
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    var keyboards = data.keyboards || [];

                    var chosen = null;

                    for (var i = 0; i < keyboards.length; i++) {
                        var kb = keyboards[i];

                        if (!kb.layout && !kb.active_keymap)
                            continue;

                        if (!chosen || kb.main)
                            chosen = kb;

                        if (kb.main)
                            break;
                    }

                    if (chosen) {
                        if (chosen.layout &&
                            chosen.layout.indexOf(",") < 0) {
                            root.code =
                                chosen.layout.slice(0, 2).toUpperCase();
                        } else if (chosen.active_keymap) {
                            root.code =
                                root.shortCode(chosen.active_keymap);
                        }
                    }
                } catch (e) {
                    console.warn("KbLayout: Hyprland parse failed:", e);
                }
            }
        }
    }

}
