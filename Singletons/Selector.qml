pragma Singleton

import QtQuick
import Quickshell

/**
 * State for the transient centred picker, shared by every selector in the pill
 * and the dock. It lives outside both the control that opens it and the window
 * that draws it, so a single picker serves the whole shell and survives the
 * opener's reload.
 *
 * `options` is a list of `{ label, value, icon? }`. `show(spec)` takes
 * `{ title, options, value, tag, owner }`: `tag` is the opener (the picker hands
 * it back on `picked`), and `owner` names the window the picker belongs to so
 * only that window draws it. `index` seeds the highlight from the current value.
 */
Singleton {
    id: root

    property bool open: false
    property string title: ""
    property var options: []
    property var value: ""
    property var tag: null
    property var owner: ""
    property int index: 0

    signal picked(var value, var tag)

    function indexOf(v) {
        for (var i = 0; i < root.options.length; i++)
            if (String(root.options[i].value) === String(v))
                return i;
        return 0;
    }

    function show(spec) {
        root.title = spec.title || "";
        root.options = spec.options || [];
        root.value = spec.value;
        root.tag = spec.tag !== undefined ? spec.tag : null;
        root.owner = spec.owner !== undefined ? spec.owner : "";
        root.index = root.indexOf(root.value);
        root.open = true;
    }

    /** Step the keyboard highlight, wrapping both ways. */
    function move(dir) {
        const n = root.options.length;
        if (n === 0)
            return;
        root.index = ((root.index + dir) % n + n) % n;
    }

    function pick(v) {
        root.open = false;
        root.picked(v, root.tag);
    }

    function activate() {
        if (root.index >= 0 && root.index < root.options.length)
            root.pick(root.options[root.index].value);
    }

    function close() {
        root.open = false;
    }
}
