import QtQuick
import Quickshell.Hyprland
import "../Singletons"

Item {
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaToggle"
        description: "Play or pause the active media player"
        onPressed: {
            var a = Players.active;
            if (a && a.canTogglePlaying)
                a.togglePlaying();
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "mediaNext"
        description: "Skip to the next track"
        onPressed: {
            var a = Players.active;
            if (a && a.canGoNext)
                a.next();
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "mediaPrev"
        description: "Skip to the previous track"
        onPressed: {
            var a = Players.active;
            if (a && a.canGoPrevious)
                a.previous();
        }
    }
}
