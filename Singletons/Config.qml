pragma Singleton
import QtQuick
import Quickshell

/**
 * Path authority for the pill, kept as one self-locating source of truth. The
 * app root is this file's own directory tree (the quickshell project folder),
 * so nothing depends on where the shell was launched from or on exported
 * UKISHIMA_* environment variables. Hyprland-compat outputs (generated modules/*,
 * hypridle.conf, hyprsunset.conf and scripts/) all resolve under the same
 * project folder.
 */
Singleton {
    id: root

    /** Absolute filesystem path of the quickshell project folder (parent of Singletons/). */
    readonly property string configDir: {
        var p = root._localPath(Qt.resolvedUrl("../"));
        return p.length > 1 && p.slice(-1) === "/" ? p.slice(0, -1) : p;
    }

    readonly property string _hypr: configDir

    function _localPath(url) {
        var s = String(url);
        if (s.indexOf("file://") === 0) {
            s = s.substring(7);
            try { s = decodeURIComponent(s); } catch (e) {}
        }
        return s;
    }

    function hyprPath() {
        var parts = Array.prototype.slice.call(arguments);
        return root.join(root._hypr, parts);
    }

    function join(base, parts) {
        var out = String(base || "");
        for (var i = 0; i < parts.length; i++) {
            var next = String(parts[i] || "");
            if (!next)
                continue;
            if (out.length === 0)
                out = next;
            else if (out.slice(-1) === "/")
                out += next.replace(/^\//, "");
            else
                out += "/" + next.replace(/^\//, "");
        }
        return out;
    }
}
