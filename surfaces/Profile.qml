pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Singletons"
import "../components"

/**
 * 我 PROFILE sub-surface: who is at this machine. Horizontal card —
 * avatar (auto-detected from ~/.face) with the login name under it on the
 * left, distro / hostname / kernel / shell / session on the right.
 * Reached from the pill's monitor icon and folds back to the hover pill on
 * the back chevron or an empty click.
 *
 * Nothing here is editable, so the row registry stays empty and the pill's
 * row-soul never lands: the profile is read-only info, not settings.
 * Distro et al are read live rather than stored — a machine that changes
 * kernels should not need the profile edited to stay true.
 */
SettingsSurface {
    id: root

    backSurface: ""
    implicitHeight: content.implicitHeight

    // Purely informational — no rows for the keyboard cursor to walk.
    rows: []
    // ── Avatar: auto-detected, no configuring ────────────────────────────

    /** First of the conventional ~/.face* files that exists, else "". */
    property string faceFile: ""
    Process {
        running: true
        command: ["sh", "-c", "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME/.face.png\" \"$HOME/.face.jpg\"; do if [ -f \"$f\" ]; then echo \"$f\"; break; fi; done"]
        stdout: SplitParser { onRead: (line) => root.faceFile = line.trim() }
    }

    // ── Live system facts ──────────────────────────────────────────────

    property string distro: ""
    property string distroId: ""
    FileView {
        id: osRelease
        path: "file:///etc/os-release"
        printErrors: false
        onLoaded: {
            const t = osRelease.text();
            let name = "", id = "";
            const lines = t.split("\n");
            for (const line of lines) {
                if (line.indexOf("PRETTY_NAME=") === 0)
                    name = line.slice(12).replace(/^"|"$/g, "");
                else if (line.indexOf("NAME=") === 0 && name === "")
                    id = line.slice(5).replace(/^"|"$/g, "");
                else if (line.indexOf("ID=") === 0)
                    root.distroId = line.slice(3).replace(/^"|"$/g, "").toLowerCase();
            }
            root.distro = name !== "" ? name : id;
        }
    }

    /**
     * Distro logo, auto-detected from the os-release ID and rendered as the
     * matching `linux-*` glyph from the JetBrainsMono Nerd Font. CachyOS maps
     * to linux-cachyos, arch to linux-archlinux, and so on; anything unmapped
     * falls back to the tux penguin so an unknown distro still gets a mark.
     */
    readonly property var distroGlyphs: ({
        "cachyos": 0xf385, "arch": 0xf303, "ubuntu": 0xf31b, "debian": 0xf306,
        "fedora": 0xf30a, "nixos": 0xf313, "manjaro": 0xf312, "garuda": 0xf337,
        "void": 0xf32e, "kali": 0xf327, "linuxmint": 0xf30e, "elementary": 0xf309,
        "solus": 0xf32d, "parrot": 0xf329, "slackware": 0xf318, "gentoo": 0xf30d,
        "centos": 0xf304, "alpine": 0xf300, "mx": 0xf33f, "pop": 0xf32a,
        "zorin": 0xf32f, "opensuse-tumbleweed": 0xf37d, "tumbleweed": 0xf37d,
        "opensuse-leap": 0xf37e, "leap": 0xf37e, "opensuse": 0xf314
    })
    readonly property string distroGlyph: String.fromCodePoint(
        root.distroGlyphs[root.distroId] !== undefined ? root.distroGlyphs[root.distroId] : 0xf31a)

    property string hostName: ""
    FileView {
        id: etcHostname
        path: "file:///etc/hostname"
        printErrors: false
        onLoaded: root.hostName = etcHostname.text().trim()
    }

    property string kernel: ""
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: SplitParser { onRead: (line) => root.kernel = line.trim() }
    }

    readonly property string shellName: {
        const sh = Quickshell.env("SHELL") || "";
        const i = sh.lastIndexOf("/");
        return i >= 0 ? sh.slice(i + 1) : sh;
    }
    readonly property string sessionType: Quickshell.env("XDG_SESSION_TYPE") || ""
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
    readonly property string wmName: Quickshell.env("XDG_CURRENT_DESKTOP") || (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "Hyprland" : "")

    //* Seconds since boot, from /proc/uptime's first field.
    property real uptimeSec: 0
    FileView {
        id: procUptime
        path: "file:///proc/uptime"
        printErrors: false
        onLoaded: {
            const v = parseFloat(procUptime.text().split(" ")[0]);
            if (!isNaN(v))
                root.uptimeSec = v;
        }
    }
    readonly property string uptime: {
        let s = Math.floor(root.uptimeSec);
        const d = Math.floor(s / 86400); s -= d * 86400;
        const h = Math.floor(s / 3600);  s -= h * 3600;
        const m = Math.floor(s / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    /** Installed package count, whichever package manager exists. */
    property string pkgCount: ""
    Process {
        running: true
        command: ["sh", "-c", "if command -v pacman >/dev/null; then pacman -Q | wc -l; elif command -v dpkg-query >/dev/null; then dpkg-query -f '${binary:Package}\\n' -W | wc -l; elif command -v rpm >/dev/null; then rpm -qa | wc -l; fi"]
        stdout: SplitParser { onRead: (line) => root.pkgCount = line.trim() }
    }

    /**
     * CPU model name, e.g. "Ryzen 7 5700U". Taken from /proc/cpuinfo and
     * trimmed to the part that identifies the chip: the vendor prefix
     * ("AMD", "Intel") and the integrated-graphics suffix ("with Radeon
     * Graphics", "with Intel UHD Graphics") are noise on a card this size,
     * and leaving them in would triple the value column's width.
     */
    property string cpu: ""
    FileView {
        id: procCpuinfo
        path: "file:///proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const m = procCpuinfo.text().match(/model name\s*:\s*(.+)/);
            if (!m)
                return;
            let name = m[1].trim();
            // Drop the vendor word and any trailing integrated-GPU clause.
            name = name.replace(/^(AMD|Intel|Apple|AuthenticAMD)\s+/i, "");
            name = name.replace(/\s+with\s+.*(Graphics|graphics)$/i, "");
            root.cpu = name;
        }
    }

    /** Used / total RAM in GiB, from /proc/meminfo. */
    property string memUsed: ""
    FileView {
        id: procMeminfo
        path: "file:///proc/meminfo"
        printErrors: false
        onLoaded: {
            const t = procMeminfo.text();
            const m1 = t.match(/MemTotal:\s+(\d+)/);
            const m2 = t.match(/MemAvailable:\s+(\d+)/);
            if (m1 && m2) {
                const total = parseInt(m1[1], 10) / 1048576;
                const used = (parseInt(m1[1], 10) - parseInt(m2[1], 10)) / 1048576;
                root.memUsed = used.toFixed(1) + " / " + total.toFixed(1) + " GiB";
            }
        }
    }

    /** Root filesystem used / total, in GiB, so it reads like MEMORY. */
    property string diskUsed: ""
    Process {
        running: true
        command: ["sh", "-c", "df -B1 / | awk 'NR==2 {printf \"%.1f / %.1f GiB\", $3/1073741824, $2/1073741824}'"]
        stdout: SplitParser { onRead: (line) => root.diskUsed = line.trim() }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "我"
            title: "PROFILE"
            showBack: true
        }

        Item { width: 1; height: 8 * root.s }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: avatarCol.implicitWidth + 24 * root.s + factsCol.implicitWidth
            implicitHeight: Math.max(avatarCol.implicitHeight, factsCol.implicitHeight)

            // Avatar + name, vertically centred against the info block.
            Column {
                id: avatarCol
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                width: 84 * root.s

                ClippingRectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72 * root.s
                    height: 72 * root.s
                    radius: 36 * root.s
                    color: Theme.frameBg

                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: root.faceFile !== "" ? "file://" + root.faceFile : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                        // Decode at the displayed size (2x for HiDPI) instead of
                        // scaling the full image on every paint — that is what
                        // made the avatar look soft/blurred.
                        sourceSize: Qt.size(144 * root.s, 144 * root.s)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !faceImg.visible
                        text: "\uf007"
                        color: Theme.iconDim
                        font.family: "JetBrainsMono NFM"
                        font.pixelSize: 22 * root.s
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.userName
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Facts: distro heading on top, then two label:value columns so
            // the card stays wide and short instead of one tall list.
            Column {
                id: factsCol
                anchors.left: avatarCol.right
                anchors.leftMargin: 24 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s

                component Fact: Item {
                    required property var modelData
                    implicitWidth: valueText.implicitWidth + 64 * root.s + 8 * root.s
                    implicitHeight: valueText.implicitHeight

                    Text {
                        id: labelText
                        text: modelData.label
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.letterSpacing: 1 * root.s
                        width: 64 * root.s
                        anchors.left: parent.left
                        // Small label and bigger value share one text baseline,
                        // not the row's vertical center — the centering is what
                        // made the values look off-line.
                        anchors.baseline: valueText.baseline
                    }
                    Text {
                        id: valueText
                        anchors.left: parent.left
                        anchors.leftMargin: 64 * root.s + 8 * root.s
                        anchors.top: parent.top
                        text: modelData.value !== "" ? modelData.value : "—"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 13 * root.s
                    }
                }

                Row {
                    spacing: 8 * root.s
                    Text {
                        text: root.distroGlyph
                        color: Theme.cream
                        font.family: "JetBrainsMono NFM"
                        font.pixelSize: 26 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.distro !== "" ? root.distro : "—"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 16 * root.s
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 28 * root.s

                    Column {
                        spacing: 7 * root.s
                        Repeater {
                            model: [
                                { label: "HOSTNAME", value: root.hostName },
                                { label: "KERNEL",   value: root.kernel },
                                { label: "WM",       value: root.wmName },
                                { label: "SHELL",    value: root.shellName },
                                { label: "SESSION",  value: root.sessionType }
                            ]
                            delegate: Fact {}
                        }
                    }

                    Column {
                        spacing: 7 * root.s
                        Repeater {
                            model: [
                                { label: "UPTIME",   value: root.uptime },
                                { label: "CPU",      value: root.cpu },
                                { label: "PACKAGES", value: root.pkgCount },
                                { label: "MEMORY",   value: root.memUsed },
                                { label: "DISK",     value: root.diskUsed }
                            ]
                            delegate: Fact {}
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 6 * root.s }
    }
}
