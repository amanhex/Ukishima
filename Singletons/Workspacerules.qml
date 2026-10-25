pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Persistent workspace→monitor map from Hyprland's workspace rules
 * (`hyprctl workspacerules`). This is the single source for the split that
 * monitors.lua declares, so the pill's dots show every assigned workspace on a
 * monitor even before it has been visited, instead of hardcoding monitor
 * names. Empty when a setup has no rules (the usual single-monitor case) and
 * the dots fall back to live workspaces. Re-read on config reload, since
 * editing monitors.lua rewrites the rules.
 *
 * Hyprland-only. WmHyprland calls this on start and on a config reload; the
 * generic provider never asks, so no `hyprctl` runs on another compositor.
 */
Singleton {
    id: root

    property var byMonitor: ({})

    function refresh() {
        proc.running = true;
    }

    Process {
        id: proc
        command: ["hyprctl", "workspacerules", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                try {
                    var rules = JSON.parse(this.text);
                    for (var i = 0; i < rules.length; i++) {
                        var ws = parseInt(rules[i].workspaceString);
                        var mon = rules[i].monitor;
                        if (!mon || isNaN(ws))
                            continue;
                        if (!map[mon])
                            map[mon] = [];
                        map[mon].push(ws);
                    }
                } catch (e) {
                    return;
                }
                for (var k in map)
                    map[k].sort(function (a, b) { return a - b; });
                root.byMonitor = map;
            }
        }
    }
}
