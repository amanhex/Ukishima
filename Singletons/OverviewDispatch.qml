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
 * ## Why every window is addressed as `window = "address:0x..."`
 *
 * The target window is `window`, and the address goes behind an `address:`
 * prefix inside that one string. Writing the field as `address = "0x..."`
 * instead is **accepted and silently ignored**: Hyprland parses the table, finds
 * no window matching its own selector, prints `ok`, and moves nothing. There is
 * no error and no non-zero exit - the drop simply does not happen, which from
 * the grid reads as the window refusing to move.
 *
 * This is not a guess. It was A/B'd against the running compositor on the two
 * dispatchers that differ between them:
 *
 *     hl.dsp.window.move({ address = "0x55a46624fd10", workspace = 3 })
 *       -> ok, window stays put
 *     hl.dsp.window.move({ window = "address:0x55a46624fd10", workspace = 3 })
 *       -> ok, window moves
 *
 * `hl.dsp.window.close` behaves identically, so right-click-to-close was broken
 * in exactly the same silent way. `focusWindow` below always had the right form,
 * which is why click-to-focus worked all along and made the *moves* look broken
 * rather than the addressing being broken.
 *
 * The rest of this tree already spells it this way - see shell.qml's
 * `minimizeWindow`/`restoreWindow`, DockBar.qml and Notifs.qml - so this file
 * was the outlier that got corrected, not the other way round.
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
        run("hl.dsp.window.close({ window = \"address:" + address + "\" })");
    }

    /**
     * Move a window to another workspace. `focus` false keeps the current window
     * focused, which is what a drag wants: focusing mid-gesture would let the
     * compositor pull focus away from the overview and abandon the drag.
     *
     * `follow = false` is the important half, and it is NOT the same thing as
     * `focus`. A move to another workspace switches the *active workspace* to the
     * destination by default, so dropping a window in a neighbouring cell yanked
     * the user out of the workspace they were sitting in - the drag ended
     * somewhere they had not asked to go. `focus` says "do not focus that
     * window"; it says nothing about which workspace stays active. `follow` is
     * the flag that answers the question the drag is actually asking.
     *
     * A/B'd on the running compositor, moving a window from ws 1 to ws 4:
     *
     *     focus = false                 -> active workspace becomes 4
     *     focus = false, follow = false -> active workspace stays 1
     *
     * The overview itself stays up either way, but the grid's focus indicator
     * and every later left-click are relative to the active workspace, so
     * following it made the drop feel like it had moved the desktop out from
     * under the pointer.
     */
    function moveWindowToWorkspace(address, workspaceId, focus) {
        run("hl.dsp.window.move({ window = \"address:" + address + "\", workspace = " + workspaceId + ", follow = false, focus = " + (focus ? "true" : "false") + " })");
    }

    //* Reposition a floating window in absolute screen coordinates.
    function moveWindowToPosition(address, x, y, focus) {
        run("hl.dsp.window.move({ window = \"address:" + address + "\", x = " + Math.round(x) + ", y = " + Math.round(y) + ", focus = " + (focus ? "true" : "false") + " })");
    }

    Process {
        id: dispatchProc

        command: ["hyprctl", "dispatch", "true"]
    }

}
