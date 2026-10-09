import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

/**
 * Lockscreen media card — album art (or the player's app icon), track and
 * live transport, sitting under the clock. Self-contained like
 * LockBattery/LockWifi: the lockscreen
 * runs as a separate process that cannot import Singletons/, components/ or
 * Theme (singletons are per-process), so the transport vectors are baked from
 * components/GlyphIcon.qml's play/pause/next/prev set and colours are white
 * like the rest of the furniture. Keep the path data in sync with GlyphIcon by
 * hand. The card draws only while a titled player exists — its own presence
 * check, the same arrangement as the battery and wifi corners — and every
 * button is a live MPRIS call, dimmed rather than hidden when the player
 * reports it cannot do that (canGoPrevious / canTogglePlaying / canGoNext).
 */
Rectangle {
    id: root

    //* The player to show: one that is playing wins, else the first with a
    //* title, so an idle titleless player (a stopped browser tab) never
    //* summons the card. Picked by object like Players.qml does on the pill
    //* side, so metadata churn re-evaluates the same way.
    readonly property var player: {
        const l = Mpris.players.values;
        var titled = null;
        for (var i = 0; i < l.length; i++) {
            var p = l[i];
            if (!p || !p.trackTitle || p.trackTitle.length === 0)
                continue;
            if (p.isPlaying)
                return p;
            if (titled === null)
                titled = p;
        }
        return titled;
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property bool canPrev: hasPlayer && player.canGoPrevious
    readonly property bool canNext: hasPlayer && player.canGoNext
    readonly property bool canToggle: hasPlayer && player.canTogglePlaying

    //* The picture in the art slot: the track's own art when the player
    //* sends it, else the player's app icon, else nothing and the music
    //* glyph draws. The same cascade as the pill's media widget, ported
    //* like everything else here because the lockscreen cannot import
    //* Singletons/Players.
    readonly property string coverSource: {
        if (!hasPlayer)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;
        return appIconFor(player);
    }

    /**
     * Players.appIconFor ported: the player's own themed app icon, matched
     * off its desktop entry so any source carries its real logo. The exact
     * entry pass is lib/apps.js byId inlined — the lockscreen keeps its
     * imports inside its own config dir — and the rest is the same
     * window-to-entry and icon-theme fallback the pill uses.
     */
    function appIconFor(p) {
        if (!p)
            return "";
        var id = (p.desktopEntry && p.desktopEntry.length > 0) ? p.desktopEntry : (p.identity || "");
        if (id.length === 0)
            return "";
        var apps = DesktopEntries.applications.values;
        var q = id.toLowerCase();
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === q && e.icon)
                return iconSourceFor(e.icon);
        }
        /**
         * Browsers expose no desktop entry, only an identity like "Mozilla zen";
         * match the entry whose id or name carries one of its words so the real
         * logo wins over the generic fallback.
         */
        if (p.identity && p.identity.length > 0) {
            var identityWords = p.identity.toLowerCase().split(/[^a-z0-9]+/);
            for (var w = 0; w < identityWords.length; w++) {
                var word = identityWords[w];
                if (word.length < 3)
                    continue;
                for (var j = 0; j < apps.length; j++) {
                    var je = apps[j];
                    if (!je || !je.icon || !je.id)
                        continue;
                    var entryWords = je.id.toLowerCase().replace(/\.desktop$/, "").split(/[^a-z0-9]+/);
                    var nameWords = String(je.name || "").toLowerCase().split(/[^a-z0-9]+/);
                    var hit = false;
                    for (var k = 0; k < entryWords.length; k++)
                        if (entryWords[k] === word) { hit = true; break; }
                    if (!hit)
                        for (var m = 0; m < nameWords.length; m++)
                            if (nameWords[m] === word) { hit = true; break; }
                    if (hit)
                        return iconSourceFor(je.icon);
                }
            }
        }
        /**
         * Registry still filling (it populates asynchronously): a raw identity
         * or entry name here would resolve to nothing useful yet and warn, so
         * stay empty and let the bindings re-evaluate once entries arrive.
         */
        if (apps.length === 0)
            return "";
        return iconSourceFor(id.toLowerCase());
    }

    /**
     * Players.iconSourceFor ported: only names the icon theme actually
     * carries resolve at load time; anything else would make the provider
     * warn and render a blank, so stay empty and let the glyph take over.
     */
    function iconSourceFor(name) {
        if (!name || name.length === 0)
            return "";
        if (Quickshell.hasThemeIcon(name))
            return Quickshell.iconPath(name, "application-x-executable");
        return "";
    }

    visible: hasPlayer
    implicitWidth: 382
    implicitHeight: 64
    radius: 19
    color: Qt.rgba(1, 1, 1, 0.14)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)

    /** One baked GlyphIcon vector: the path lives in a 24-unit square and
     *  scales to the item, filled for the transport set, stroked for the
     *  music-note art fallback. */
    component Glyph: Item {
        id: glyph

        property string d: ""
        property color tint: "#ffffff"
        property bool filled: true

        readonly property real u: Math.min(width, height) / 24

        Shape {
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: glyph.u
            transformOrigin: Item.Center

            ShapePath {
                strokeWidth: glyph.filled ? 0 : 1.7
                strokeColor: glyph.filled ? "transparent" : glyph.tint
                fillColor: glyph.filled ? glyph.tint : "transparent"

                PathSvg {
                    path: glyph.d
                }
            }
        }
    }

    /** One transport button: glyph on a hover disc, or the white play seal.
     *  `allowed` gates the click and dims the whole button — the button stays
     *  in place so the row never re-flows between tracks. */
    component Btn: Item {
        id: btn

        property string d: ""
        property string label: ""
        property bool allowed: true
        property bool seal: false

        signal clicked

        opacity: allowed ? 1 : 0.3

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: btn.seal || mouse.containsMouse
            color: btn.seal ? (mouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)) : Qt.rgba(1, 1, 1, 0.16)

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            width: 24
            height: 24
            d: btn.d
            //* Same inversion as LockSurface's enter circle: dark glyph on
            //* the bright white seal, light glyph on glass.
            tint: btn.seal ? "#14181a" : "#ffffff"
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.allowed ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: btn.allowed
            onClicked: btn.clicked()
        }

        Accessible.role: Accessible.Button
        Accessible.name: btn.label
        Accessible.pressed: mouse.pressed
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // album art — ClippingRectangle clips to radius (plain clip ignores it)
        Item {
            id: art

            width: 40
            height: 40

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.10)

                Image {
                    id: cover

                    anchors.fill: parent
                    source: root.coverSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                }
            }

            // last resort — no art and no resolvable app icon for the player (or art still loading)
            Glyph {
                anchors.centerIn: parent
                width: 20
                height: 20
                d: "M9 18V5l12-2v13 M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0z M21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"
                tint: Qt.rgba(1, 1, 1, 0.55)
                filled: false
                visible: cover.status !== Image.Ready
            }
        }

        Item {
            width: 170
            height: 40

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: 170
                    text: root.hasPlayer ? root.player.trackTitle : ""
                    color: "#ffffff"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: "Adwaita Sans"
                    font.pointSize: 11
                    font.weight: Font.Medium
                }

                Text {
                    width: 170
                    text: root.hasPlayer ? (root.player.trackArtists || root.player.trackArtist) : ""
                    color: "#ffffff"
                    opacity: 0.7
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: "Adwaita Sans"
                    font.pointSize: 9
                }
            }
        }

        // transport — live MPRIS calls on the picked player
        Item {
            width: 120
            height: 40

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Btn {
                    width: 36
                    height: 36
                    d: "M18 5l-9 7 9 7z M6 5h2v14H6z"
                    label: "Previous track"
                    allowed: root.canPrev
                    onClicked: if (root.player) root.player.previous()
                }

                Btn {
                    width: 36
                    height: 36
                    d: root.playing ? "M8 5h3v14H8z M13 5h3v14h-3z" : "M7 5l12 7-12 7z"
                    label: root.playing ? "Pause" : "Play"
                    allowed: root.canToggle
                    seal: true
                    onClicked: if (root.player) root.player.togglePlaying()
                }

                Btn {
                    width: 36
                    height: 36
                    d: "M6 5l9 7-9 7z M16 5h2v14h-2z"
                    label: "Next track"
                    allowed: root.canNext
                    onClicked: if (root.player) root.player.next()
                }
            }
        }
    }
}
