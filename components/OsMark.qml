import QtQuick
import Quickshell.Io
import "../Singletons"

/**
 * The OS brand mark that opens the profile surface: a small filled distro logo
 * leading the expanded pill like the logo at the left end of a waybar. The logo
 * is picked at load time from /etc/os-release — the shell's one brand element,
 * so it should match whatever the host actually runs. Distro ID looks up a glyph
 * in the baked set (arch, debian, fedora, ubuntu, nixos, gentoo); unknown IDs
 * fall back through ID_LIKE (manjaro → arch, pop → ubuntu …) and finally to the
 * generic linux penguin, so a derivative or uncommon distro still gets a mark.
 * Dim at rest, cream under the pointer.
 */
Item {
    id: root

    property real s: 1
    signal activated()

    width: 14 * root.s
    height: 14 * root.s

    //* Distro ID (or an ID_LIKE entry) → baked glyph name. Everything else gets "linux".
    readonly property var distros: ({
        "arch": "arch",
        "debian": "debian",
        "fedora": "fedora",
        "ubuntu": "ubuntu",
        "nixos": "nixos",
        "gentoo": "gentoo"
    })

    readonly property string glyph: {
        var release = releaseFile.text() || "";
        var id = "", like = "";
        var line;
        for (var i = 0; i < release.length; ) {
            var eol = release.indexOf("\n", i);
            if (eol < 0) eol = release.length;
            line = release.substring(i, eol);
            if (line.indexOf("ID=") === 0) id = line.substring(3).replace(/["']/g, "");
            else if (line.indexOf("ID_LIKE=") === 0) like = line.substring(8).replace(/["']/g, "");
            i = eol + 1;
        }
        if (root.distros[id] !== undefined)
            return root.distros[id];
        var likes = like.split(/\s+/);
        for (var k = 0; k < likes.length; k++)
            if (root.distros[likes[k]] !== undefined)
                return root.distros[likes[k]];
        return "linux";
    }

    FileView {
        id: releaseFile
        path: "/etc/os-release"
        blockLoading: true
        watchChanges: false
        printErrors: false
    }

    GlyphIcon {
        anchors.fill: parent
        name: root.glyph
        color: area.containsMouse ? Theme.cream : Theme.dim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.s
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Tooltip {
        s: root.s
        placement: "below"
        title: "Profile"
        show: area.containsMouse
    }
}