import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

/**
 * Overview action helpers — Tide Island's `HyprlandDispatch`, reduced to what
 * the workspace overview uses and pointed at this shell's dispatcher conventions.
 *
 * Every call goes through `hyprctl dispatch` with the **Lua** dispatcher form
 * (`hl.dsp.…`), which is the only form Hyprland 0.55+ accepts; the old keyword
 * form is a silent no-op there. That is already the convention in this tree (see
 * Notifs.qml), so the port keeps it rather than Tide's own wrapper.
 *
 * Nothing here reports success. A dispatch either lands or it does not, and the
 * overview reacts to the compositor's own events rather than to a return value —
 * so a move that fails self-corrects on the next snapshot instead of leaving
 * the grid and the desktop disagreeing.
 *
 * `QtQuick` is imported for `Component` alone; without it this file parses but
 * fails to instantiate with "Non-existent attached object", and because every
 * other singleton transitively reaches this one through `Notifs`, that takes
 * the whole shell down rather than just the overview.
 */
Singleton {
    id: root

    function run(dispatcher) {
        //* One Process, re-commanded per call. Quickshell restarts a finished
        //* Process, so back-to-back dispatches (move + reposition a floating
        //* window) do not need a queue.
        dispatchProc.command = ["hyprctl", "dispatch", dispatcher];
        dispatchProc.running = true;
    }

    function focusWorkspace(id) {
        run("hl.dsp.focus({ workspace = " + id + " })");
    }

    //* `address:` is required — a bare hex address is read as a workspace id.
    function focusWindow(address) {
        run("hl.dsp.focus({ window = \"address:" + address + "\" })");
    }

    function closeWindow(address) {
        run("hl.dsp.window.close({ address = \"" + address + "\" })");
    }

    /**
     * Move a window to another workspace. `focus` false keeps the current window
     * focused, which is what a drag wants: focusing mid-gesture would let the
     * compositor pull focus away from the overview and abandon the drag.
     */
    function moveWindowToWorkspace(address, workspaceId, focus) {
        run("hl.dsp.window.move({ address = \"" + address + "\", workspace = " + workspaceId + ", focus = " + (focus ? "true" : "false") + " })");
    }

    //* Reposition a floating window in absolute screen coordinates.
    function moveWindowToPosition(address, x, y, focus) {
        run("hl.dsp.window.move({ address = \"" + address + "\", x = " + Math.round(x) + ", y = " + Math.round(y) + ", focus = " + (focus ? "true" : "false") + " })");
    }

    Process {
        id: dispatchProc

        command: ["hyprctl", "dispatch", "true"]
    }

}
