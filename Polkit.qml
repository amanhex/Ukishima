import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import "Singletons"
import "components/polkit"

/**
 * Built-in polkit authentication agent, dialog ported from midnight-shell.
 *
 * Registers Quickshell's PolkitAgent on D-Bus (no external agent such as
 * hyprpolkitagent or polkit-gnome needed or wanted — two agents would fight
 * over registration and double-prompt). One PolkitDialog per screen; only
 * the focused monitor's instance activates, as an Overlay layer with
 * exclusive keyboard focus, and hides completely when no request is pending.
 *
 * Only the battle-tested PolkitAgent/PolkitFlow members are used
 * (isActive, flow.message, flow.submit(), flow.cancelAuthenticationRequest(),
 * flow.supplementaryMessage, flow.supplementaryIsError, plus the
 * authenticationFailed/authenticationSucceeded signals for error feedback).
 */
Scope {
    id: root

    PolkitAgent {
        // Handles D-Bus registration automatically.

        id: polkitAgent
    }

    Variants {
        model: Quickshell.screens

        PolkitDialog {
            agent: polkitAgent
            isFocused: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : false
        }

    }

}
