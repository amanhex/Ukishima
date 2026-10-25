pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * 更新 UPDATE sub-surface: pulls the latest from GitHub and reloads the shell
 * in place. Reached from the Appearance index and folds back to it on the
 * back chevron or an empty click.
*/
SettingsSurface {
    id: root

    backSurface: "appearance"
    implicitHeight: content.implicitHeight

    property string status: ""
    property bool busy: false
    /** True once a probe has run successfully and knows the remote state. */
    property bool checked: false
    /** Commits on origin/master that this checkout is behind. */
    property int pending: 0
    /** True when checked and origin/master has new commits to fast-forward. */
    readonly property bool updateAvailable: checked && !busy && pending > 0
    /** Shared guard for both updater commands: only a clean official release checkout. */
    readonly property string releaseGuard:
        "repo=$1\n" +
        "branch=$(git -C \"$repo\" branch --show-current 2>/dev/null) || exit 21\n" +
        "remote=$(git -C \"$repo\" remote get-url origin 2>/dev/null) || exit 21\n" +
        "upstream=$(git -C \"$repo\" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || exit 21\n" +
        "[ \"$branch\" = master ] && [ \"$upstream\" = origin/master ] || exit 21\n" +
        "case \"$remote\" in https://github.com/amanhex/Ukishima.git|https://github.com/amanhex/Ukishima|git@github.com:amanhex/Ukishima.git) ;; *) exit 21 ;; esac\n" +
        "changes=$(git -C \"$repo\" status --porcelain 2>/dev/null) || exit 21\n" +
        "[ -z \"$changes\" ] || exit 22\n"
    /** Inline result of the manual dependency check; empty until one has run. */
    property string depStatus: ""
    property bool depBusy: false
    /** True once a manual check has run, so the report link knows it is useful. */
    property bool depChecked: false
    /** Full records for what is missing: [{ id, why, pkg }], required first. */
    property var depList: []
    /** How many of depList are required rather than optional. */
    property int depRequiredCount: 0
    /**
     * Has a verdict for the run currently in flight arrived yet?
     *
     * Both halves of the answer are needed and neither alone is enough.
     * onStreamFinished fires before onExited, so the two callbacks for one run
     * are not interchangeable: only the first can carry the output, and only
     * the second reliably fires — a run that produced nothing never gets a
     * verdict at all. The flag is what tells onExited whether applyDepVerdict
     * already ran, and so whether an empty result means this check produced
     * nothing or that it simply has not reported yet. Reset on exit, so it can
     * never carry over into the next run and suppress its verdict.
    */
    property bool depVerdictSeen: false
    /**
     * Entries actually rendered, capped so the surface cannot grow without
     * bound. The cap guards a real failure mode, not a hypothetical one: the
     * check runs in a child process, and if that process ever inherits a
     * stripped environment then `command -v` fails for everything at once and
     * every dependency in the manifest reads as missing — fifteen entries of
     * three lines each, well past the screen. The generated report is the full
     * set, so the overflow is handed off there rather than dropped silently.
    */
    readonly property int depVisibleCap: 6
    readonly property var depVisible: depList.length > depVisibleCap
        ? depList.slice(0, depVisibleCap)
        : depList
    readonly property int depHiddenCount: depList.length - depVisible.length
    /**
     * The one-line verdict. Deliberately a count and not a list of names: the
     * list is rendered directly below, so repeating the names here would just
     * be the same information twice on one screen.
    */
    readonly property bool depCheckFailed: depStatus.startsWith("Could not")
    readonly property bool depReportUseful: depChecked && depList.length > 0 && !depCheckFailed
    rows: [
        { item: updateRow, kind: "activate", activate: function () { root.updateAvailable ? root.doUpdate() : root.checkUpdates(); } },
        { item: depsRow, kind: "activate", activate: function () { root.checkDeps(); } }
    ]

    function checkUpdates() {
        if (root.busy)
            return;
        root.busy = true;
        root.status = "Checking for updates...";
        checkProc.running = true;
    }

    function doUpdate() {
        if (root.busy || !root.updateAvailable)
            return;
        root.busy = true;
        root.status = "Updating Ukishima...";
        updateProc.running = true;
    }

    function setUpdateCount(text) {
        var value = String(text).trim();
        if (!/^(0|[1-9][0-9]*)$/.test(value)) {
            root.busy = false;
            root.checked = false;
            root.pending = 0;
            root.status = "Couldn't read update status. Try again.";
            return;
        }
        var n = parseInt(value, 10);
        root.pending = n;
        root.checked = true;
        root.status = n > 0 ? "Update available." : "Ukishima is up to date.";
        root.busy = false;
    }

    /**
     * Dependency check. Deliberately shells out to the same
     * scripts/check-deps.sh the installer and the post-update path use, so the
     * answer here cannot drift from what those report.
     *
     * Deliberately does *not* clear depList/depStatus up front: the previous verdict is still
     * true, and blanking it would make the surface flicker empty on each reopen
     * for the few milliseconds the check takes. applyDepVerdict() owns the
     * post-state, including every failure path.
    */
    function checkDeps() {
        if (root.depBusy)
            return;
        root.depBusy = true;
        root.depVerdictSeen = false;
        depProc.running = true;
    }

    /**
     * Turn one line of `check-deps.sh --json` into the surface's list.
     *
     * Reached from a StdioCollector, not from Process.onExited: that signal is
     * (int exitCode, QProcess::ExitStatus) and carries no stdout. Reading a
     * second parameter as if it were the output is not a crash — for a normal
     * exit it is the string "0", and JSON.parse("0") happily returns the number
     * 0 — so every field then reads as absent, both lists come out empty, and
     * the surface reports "All dependencies satisfied" on a system that is
     * missing things. A silent, confidently wrong answer, which is the worst
     * kind this feature could produce.
    */
    function applyDepVerdict(text) {
        // Output arrived at all, which means a check did run. Set before parsing
        // so that a parse failure is reported as such, rather than being
        // overwritten by the onExited "produced nothing" fallback.
        root.depVerdictSeen = true;
        root.depChecked = true;
        var r = null;
        try {
            r = JSON.parse(String(text).trim());
        } catch (e) {
            r = null;
        }
        // Checking that the parse did not throw is not enough. JSON.parse accepts
        // plenty of things that are not a report: parse("0") is the number 0 and
        // parse("null") is null, neither of which throws. Both would go on to
        // read as a report with no missing dependencies in it, and the surface
        // would say "All dependencies satisfied" about a system it had learned
        // nothing at all. So the shape is checked, not just the parse.
        if (r === null || typeof r !== "object" || Array.isArray(r)) {
            root.depList = [];
            root.depRequiredCount = 0;
            root.depStatus = "Could not read the dependency report";
            return;
        }
        // Required first so the alarming entries sit at the top of the list,
        // with `required` carried per-entry for the delegate to colour by.
        // `why` is dropped here even though the script sends it: the list does
        // not render it, and a field nothing reads is one more thing to keep
        // true. It is still in the report, which is where it belongs.
        var core = r.missingCore || [];
        var opt = r.missingOptional || [];
        var all = [];
        core.forEach(function (d) { all.push({ id: d.id, pkg: d.pkg, required: true }); });
        opt.forEach(function (d) { all.push({ id: d.id, pkg: d.pkg, required: false }); });
        root.depList = all;
        root.depRequiredCount = core.length;
        if (core.length > 0) {
            root.depStatus = core.length + (core.length === 1 ? " required dependency missing" : " required dependencies missing");
        } else if (opt.length > 0) {
            root.depStatus = "All required present · " + opt.length + " optional not installed";
        } else {
            root.depStatus = "All dependencies satisfied";
        }
    }

    function openDepReport() {
        depPageProc.running = true;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "更"
            title: "UPDATE"
            showBack: true
        }

Item { width: 1; height: 10 * root.s }
        SettingsRow {
            id: updateRow
            surface: root
            name: root.busy ? root.status : (root.updateAvailable ? "Update Ukishima" : (root.checked ? root.status : "Check for Updates"))
            // "refresh", not "refresh-cw". GlyphIcon holds no such name, and an
            // unknown name is not a fallback shape — the lookup ends at
            // { d: "" }, which draws nothing at all. The row was rendering its
            // leading glyph as empty space, which is part of why the two sections
            // here read as one row with an icon and one without.
            icon: "refresh"
            // The verdict goes in the row's own caption, not in a separate
            // full-width line underneath. Three stacked standalone Texts read as
            // a column of disconnected grey sentences floating between the two
            // rows, and each one had to be inset and aligned by hand. In the
            // caption slot the answer sits directly under the label it belongs
            // to and SettingsRow does the insetting, so there is only ever one
            // left edge to agree with.
            //
            sub: {
                if (root.updateAvailable)
                    return root.pending + (root.pending === 1 ? " update available — select to install" : " updates available — select to install");
                return "";
            }

            // The spinner, and only the spinner. This is the trailing control
            // slot, which is a different slot from the leading `icon` above —
            // that is why a glyph can live here without doubling up on `icon`.
            // Visible only while running, because a second `refresh` sitting
            // still beside the row's own `refresh` while nothing is happening
            // would be the same glyph twice for no reason. The resting state
            // leaves the slot to the update-available dot.
            GlyphIcon {
                visible: root.busy
                width: 16 * root.s
                height: 16 * root.s
                name: "refresh"
                color: root.focusRowItem === updateRow ? Theme.cream : Theme.iconDim
                stroke: 1.9

                RotationAnimation on rotation {
                    running: root.busy
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8 * root.s
                visible: root.updateAvailable
                width: 7 * root.s
                height: 7 * root.s
                radius: width / 2
                color: Theme.vermLit

                SequentialAnimation on opacity {
                    running: root.updateAvailable
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }

        /**
         * The gap that makes two sections out of what used to be one list.
         *
         * SettingsRow already draws a hairline under every row that is not
         * `last`, so there is a rule between these two. A rule alone is not
         * enough to read as a boundary, though — rows are separated by rules
         * too, and at 12 units the pair sat close enough to look like four
         * consecutive lines with two of them suddenly carrying a caption. The
         * extra space is what turns the rule into a division.
        */
        Item { width: 1; height: 10 * root.s }

        SettingsRow {
            id: depsRow
            surface: root
            name: root.depBusy ? "Checking dependencies..." : (root.depChecked ? "Check again" : "Check dependencies")
            // "layers" for the same reason the row above got a working `icon`:
            // the two sections should be recognisable apart at a glance, and
            // right now one of them owns the leading glyph column while the other
            // leaves it empty. Two rows, two glyphs, one shape.
            icon: "layers"
            // Before the first check the caption says what the button does; after
            // it, the caption *is* the answer. One slot, never both, so the row
            // cannot show an instruction and a verdict at once and leave the
            // reader unsure which one is current.
            sub: root.depChecked ? root.depStatus : "verify this system has what the current code needs"
            last: true

            /**
             * The verdict mark, and the only thing on this row that says a check
             * has actually run — so it must not exist before one is asked for.
             *
             * The leading `icon` above and this trailing glyph are separate
             * slots, which is why `layers` here adds no second mark. This one is
             * a check when nothing required is missing and a cross when something
             * is, because a tick that appeared whether or not the answer was yes
             * would be asserting a result the check never gave — the exact
             * failure the gating below exists to prevent, one level up.
             *
             * Dimmed rather than spun while running. "check" is a real glyph, not
             * a spinner frame, and rotating it would read as nonsense; the check
             * takes well under a second, so the dim is enough to acknowledge it.
            */
            GlyphIcon {
                visible: root.depBusy || root.depChecked
                width: 16 * root.s
                height: 16 * root.s
                name: root.depRequiredCount > 0 ? "close" : "check"
                color: root.depRequiredCount > 0
                       ? Theme.vermLit
                       : (root.focusRowItem === depsRow ? Theme.cream : Theme.iconDim)
                stroke: 1.9
                opacity: root.depBusy ? 0.45 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }

        /**
         * The dependency result, inset to line up with the row labels above it.
         *
         * The inset is not cosmetic. SettingsRow places its own text 14 + 17 +
         * 13 = 44 scale units in, to clear the leading icon, and leaves 30 more
         * at the right for the trailing control. A list laid out from the
         * surface's own left edge therefore sat a full icon-width to the left of
         * the "Check dependencies" it belongs to — two unrelated-looking columns
         * stacked in one panel. Insetting everything below puts it on the same
         * left edge as every row, and the right inset stops the last entry
         * running under the tick.
         *
         * The wrapper is a plain Item rather than a Column, and that is the
         * whole trick: this sits inside `content`, which is itself a Column, and
         * a Positioner places its own children — anchors on them are ignored,
         * with a warning. An Item can be anchored; the Column goes one level
         * deeper, inside it, where anchoring is allowed again.
        */
        Item {
            id: depBlock
            width: content.width
            height: depCol.implicitHeight

            Column {
                id: depCol
                anchors.left: parent.left
                anchors.leftMargin: 44 * root.s
                anchors.right: parent.right
                anchors.rightMargin: 30 * root.s
                spacing: 0

                /**
                 * Section label, shown only when that half of the list is non-empty.
                 * Left-aligned, not centred: the entries underneath it are left-
                 * aligned to the row label's own edge, and a centred heading over a
                 * left-aligned list is the one combination that makes a column look
                 * accidental. Every line in this block now shares a single left edge,
                 * which is the whole reason the block reads as one unit.
                */
                Text {
                    visible: root.depRequiredCount > 0
                    width: parent.width
                    text: "REQUIRED"
                    color: Theme.vermDim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                    topPadding: 14 * root.s
                    bottomPadding: 2 * root.s
                }

                Text {
                    visible: root.depRequiredCount === 0 && root.depList.length > 0
                    width: parent.width
                    text: "OPTIONAL"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                    topPadding: 14 * root.s
                    bottomPadding: 2 * root.s
                }

                /**
                 * One entry per missing dependency: the id, and the package that
                 * provides it. Required entries are inked in the alarm colour and
                 * optional ones stay dim, so the list reads in priority order
                 * without needing to be split into two repeaters.
                 *
                 * Two things are deliberately absent. The manifest's `why`, because
                 * it is written for the report page — a sentence, in a column wide
                 * enough to read a sentence in — and under every id it turned a list
                 * of six into a wall of prose to scroll past to reach the package
                 * name. And the package line when it is just the id again, which for
                 * most entries it is: showing "ghostty" over "ghostty" is noise, and
                 * noise in a list this short costs a visible row. The report has the
                 * pairing in full either way.
                */
                Repeater {
                    model: root.depVisible

                    delegate: Column {
                        id: depItem
                        required property var modelData

                        // depCol.width by id, not parent.width: a Repeater's
                        // delegates are not reliably parented to the positioner, and
                        // parent.width would collapse to the Repeater's own zero
                        // width without any error. Referencing the inset column
                        // explicitly is what keeps the entries aligned with the
                        // labels above — depBlock is the full surface width, so
                        // sizing to that would put them back out at the left edge.
                        width: depCol.width
                        spacing: 1 * root.s
                        topPadding: 4 * root.s
                        bottomPadding: 4 * root.s

                        // The package line, minus anything that just repeats the id
                        // above it. Most entries are named after their own package,
                        // and "ghostty" printed over "ghostty" is a wasted row in a
                        // list this short; but an entry can list several packages and
                        // only one of them be the id, so the whole list is filtered
                        // rather than the line dropped on a single comparison. If
                        // nothing survives the filter the line is not rendered at all.
                        readonly property var pkgOnly: {
                            var out = [];
                            var pk = modelData.pkg || [];
                            for (var i = 0; i < pk.length; i++) {
                                if (pk[i] !== modelData.id) out.push(pk[i]);
                            }
                            return out;
                        }
                        readonly property string pkgText: pkgOnly.join(", ")

                        Text {
                            width: parent.width
                            text: depItem.modelData.id
                            color: depItem.modelData.required ? Theme.vermLit : Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: depItem.pkgText.length > 0
                            // "install X" is the actual next step, and the id is often
                            // not the package name — bluetoothctl comes from
                            // bluez-utils, the power profiles from a unit with no
                            // binary at all.
                            text: depItem.pkgText
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            elide: Text.ElideRight
                        }
                    }
                }

                /**
                 * What the cap held back. Says how many, so the list reads as
                 * truncated on purpose rather than as the whole answer — a list that
                 * silently stops at six is indistinguishable from one where six is
                 * the truth.
                 *
                 * Left-aligned like everything else in this block. Centring it put
                 * the one line that refers back to the list somewhere the list was
                 * not.
                */
                Text {
                    visible: root.depHiddenCount > 0
                    width: parent.width
                    text: "+" + root.depHiddenCount + " more — see the full report"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    wrapMode: Text.WordWrap
                    topPadding: 4 * root.s
                }

                /**
                 * Opens the same generated HTML report the post-update path uses, for
                 * the install commands and anything the compact list above leaves
                 * out. One fixed file, rewritten in place, so repeated checks never
                 * pile up copies and this link always points at the current report.
                */
                Item {
                    id: depLink
                    visible: root.depReportUseful && !root.depBusy
                    width: parent.width
                    height: visible ? 26 * root.s : 0

                    TapHandler {
                        onTapped: root.openDepReport()
                    }

                    Text {
                        // Left, not centred, and vertically centred in the tap target
                        // so the whole row stays clickable. Centring the label made
                        // the one interactive line in the block the one line that did
                        // not line up with anything above it.
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open full report with install commands"
                        color: depLinkHover.hovered ? Theme.cream : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.underline: depLinkHover.hovered
                    }

                    HoverHandler { id: depLinkHover }
                }
            }
        }
    }

    Process {
        id: checkProc
        command: ["sh", "-c",
            root.releaseGuard +
            "git -C \"$repo\" fetch --quiet origin 2>/dev/null || exit 23\n" +
            "count=$(git -C \"$repo\" rev-list --count HEAD..origin/master 2>/dev/null) || exit 21\n" +
            "printf '%s\\n' \"$count\"\n",
            "ukishima-check", Config.configDir]
        stdout: StdioCollector {
            id: checkOutput
        }
        onExited: function (exitCode) {
            if (exitCode === 0 && root.busy) {
                root.setUpdateCount(checkOutput.text);
            } else if (root.busy) {
                root.busy = false;
                root.checked = false;
                root.pending = 0;
                if (exitCode === 21)
                    root.status = "Updater supports clean official release installs only.";
                else if (exitCode === 22)
                    root.status = "Local changes found. Save them before updating.";
                else if (exitCode === 23)
                    root.status = "Couldn't reach updates. Check your connection.";
                else
                    root.status = "Couldn't check this installation.";
            }
        }
    }

    Process {
        id: updateProc
        command: ["sh", "-c",
            root.releaseGuard +
            "git -C \"$repo\" fetch --quiet origin 2>/dev/null || exit 23\n" +
            "changes=$(git -C \"$repo\" status --porcelain 2>/dev/null) || exit 21\n" +
            "[ -z \"$changes\" ] || exit 22\n" +
            "git -C \"$repo\" merge --ff-only --quiet origin/master 2>/dev/null || exit 24\n",
            "ukishima-update", Config.configDir]
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.busy = false;
                if (exitCode === 21)
                    root.status = "Updater supports clean official release installs only.";
                else if (exitCode === 22)
                    root.status = "Local changes found. Save them before updating.";
                else if (exitCode === 23)
                    root.status = "Couldn't reach updates. Check your connection.";
                else
                    root.status = "Update couldn't be fast-forwarded. Review the release checkout.";
                return;
            }
            root.pending = 0;
            root.checked = true;
            root.status = "Successfully updated!";
            postUpdateProc.running = true;
        }
    }

    /**
     * Post-update step: runs after the safe fast-forward succeeds and before the reload, and
     * is the only place the dependency check can live.
     *
     * It has to be here, in a process driven by the still-running outgoing
     * shell, rather than inside the shell after the reload. The whole reason to
     * re-check is that an update can introduce a requirement the user does not
     * have — and one of those can be an unresolvable QML import that stops the
     * shell loading at all. Shell code that failed to load cannot report its own
     * missing dependencies, and by the time a reloaded shell existed the one
     * moment where a broken shell could still say something would have passed.
     * So the check runs with the new code already on disk, against the old shell
     * that is still alive, immediately before the reload.
     *
     * It must therefore finish before the reload, hence its own Process rather
     * than being fired and forgotten: a reload mid-check would kill the very
     * process doing the reporting. `timeout` bounds it — the same guard the
     * brightness paths use — because a hung notification server must not be able
     * to strand the user on an "Updating..." surface that never reloads. The
     * check's own contract is to never fail the update, so every error path in
     * it is swallowed here.
    */
    Process {
        id: postUpdateProc
        command: ["timeout", "10", Config.hyprPath("scripts", "check-deps.sh"), "--report"]
        onExited: reloadTimer.start()
    }

    /**
     * The dependency check itself. Note where the output is read from: the
     * verdict arrives through a StdioCollector, not through onExited. That
     * signal is (int exitCode, QProcess::ExitStatus) and carries no stdout.
     * Treating its second parameter as the output is not a crash either — on a
     * normal exit it is the string "0", and JSON.parse("0") returns the number
     * 0 — so every field reads as absent, both lists come out empty, and the
     * surface cheerfully reports "All dependencies satisfied" on a system that
     * is missing things. Hence the collector, like every other process here.
    */
    Process {
        id: depProc
        running: false
        command: [Config.hyprPath("scripts", "check-deps.sh"), "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyDepVerdict(this.text)
        }
        onExited: function (exitCode) {
            // Busy is cleared here rather than in onStreamFinished, because a run
            // that produced no output at all still has to stop looking busy.
            root.depBusy = false;
            root.depChecked = true;
            if (!root.depVerdictSeen) {
                // No output means the script never got as far as a verdict: it
                // writes every failure to stderr and exits non-zero, so this is
                // jq or the manifest being gone, not a clean system. Clear the
                // list here because no collector callback will do it.
                root.depList = [];
                root.depRequiredCount = 0;
                root.depStatus = "Could not run the check — jq and the manifest are required";
            }
            root.depVerdictSeen = false;
        }
    }

    /** Opens the generated HTML report — the full list, which a line cannot hold. */
    Process {
        id: depPageProc
        command: [Config.hyprPath("scripts", "check-deps.sh"), "--page"]
    }

    Timer {
        id: reloadTimer
        interval: 1000
        onTriggered: Quickshell.reload(true)
    }
}
