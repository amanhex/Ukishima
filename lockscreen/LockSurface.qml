import M3Shapes
// Ukishima lockscreen — matches reference image:
// blurred desktop, date + big time top, avatar + bryly + pill bottom.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Rectangle {
    id: root

    required property LockContext context
    // WlSessionLockSurface passed from shell.qml for per-screen screencopy
    required property var lockSurface
    readonly property string home: Quickshell.env("HOME")
    readonly property string userName: context.userName
    readonly property string facePath: home + "/.face"
    // grim pre-capture from lock.sh (hyprlock screenshot equivalent),
    // then live ukishima wallpaper, then static fallback
    readonly property string lockShot: "/tmp/ukishima-lock.png"
    readonly property string stateWallpaper: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/ukishima-wallpaper"
    readonly property string wallpaperFallback: home + "/Pictures/Wallpapers/current_wallpaper.jpg"

    // Shuffled dot-morph queue, like polkit's shapeQueue: each typed char
    // pops in as a random shape then settles into a dot.
    readonly property list<int> shapeQueue: {
        const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Fan, MaterialShape.Arrow, MaterialShape.SemiCircle, MaterialShape.Triangle, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Sunny, MaterialShape.VerySunny, MaterialShape.Cookie4Sided, MaterialShape.Ghostish, MaterialShape.SoftBurst];
        for (let i = shapes.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [shapes[i], shapes[j]] = [shapes[j], shapes[i]];
        }
        return shapes;
    }
    readonly property bool fieldInError: context.showFailure
    //* Clock format follows the desktop General setting (DisplaySurface timeRow
    //* -> Flags.time12h), and the lock battery shimmer follows the Battery
    //* surface toggle (Flags.batteryShimmer && !reduceMotion). Read-only: the
    //* lockscreen runs as a separate process that cannot import ../Singletons,
    //* and a partial JsonAdapter must never write back to the shared
    //* flags.json (writeAdapter would clobber every other key) — so this only
    //* parses the file and never writes it.
    property bool use12h: false
    property bool batteryShimmerOn: true

    function syncSharedFlags() {
        try {
            var shared = JSON.parse(sharedFlags.text());
            if (shared && typeof shared.time12h === "boolean")
                root.use12h = shared.time12h;

            root.batteryShimmerOn = (!shared || shared.batteryShimmer !== false) && (!shared || shared.reduceMotion !== true);
        } catch (e) {
        }
    }

    FileView {
        id: sharedFlags

        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.syncSharedFlags()
        onFileChanged: reload()
        onLoadFailed: {
            root.use12h = false;
            root.batteryShimmerOn = true;
        }
    }

    color: "#0b0d0c"
    focus: true
    Keys.onEscapePressed: context.currentText = ""
    Keys.onEnterPressed: context.tryUnlock()
    Keys.onReturnPressed: context.tryUnlock()
    // exit fade on successful unlock (shell sets closing, then quits)
    opacity: context.closing ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    // entrance choreography, Caelestia initAnim style:
    // backdrop settles (fade + zoom + focus pull), clock drifts down,
    // auth cluster rises — staggered so the lock "assembles" smoothly
    Component.onCompleted: showAnim.start()

    ParallelAnimation {
        id: showAnim

        NumberAnimation {
            target: bgLayer
            property: "opacity"
            from: 0
            to: 1
            duration: 450
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bgLayer
            property: "scale"
            from: 1.05
            to: 1
            duration: 750
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bgBlur
            property: "blurMax"
            from: 64
            to: 32
            duration: 750
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 90
            }

            ParallelAnimation {
                NumberAnimation {
                    target: clockCol
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: clockShift
                    property: "y"
                    from: -22
                    to: 0
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

        }

        SequentialAnimation {
            PauseAnimation {
                duration: 180
            }

            ParallelAnimation {
                NumberAnimation {
                    target: authCol
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: authShift
                    property: "y"
                    from: 26
                    to: 0
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

        }

        SequentialAnimation {
            PauseAnimation {
                duration: 140
            }

            ParallelAnimation {
                NumberAnimation {
                    target: lockBattery
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 500
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: lockWifi
                    property: "opacity"
                    from: 0
                    to: 0.9
                    duration: 500
                    easing.type: Easing.OutCubic
                }
            }

        }

    }

    // ── Background ──
    // grim file first (real desktop, captured pre-lock), then ScreencopyView,
    // then wallpaper file. Matches hyprlock `path = screenshot` + Caelestia useWallpaper.
    Item {
        id: bgLayer

        anchors.fill: parent
        opacity: 0
        scale: 1.05

        // 1) grim pre-capture — most reliable, no ext-session-lock race
        Image {
            id: grimShot

            anchors.fill: parent
            source: "file://" + root.lockShot
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: false
        }

        // 2) Per-screen live capture when grim missing (Caelestia screencopyBackground).
        // live:false = single frame, avoids DPMS/wake crash loop.
        ScreencopyView {
            id: bgShot

            anchors.fill: parent
            captureSource: root.lockSurface ? root.lockSurface.screen : null
            live: false
            visible: !grimShot.visible && hasContent
        }

        // One blurred layer over whichever source is live.
        MultiEffect {
            id: bgBlur

            anchors.fill: parent
            source: grimShot.status === Image.Ready ? grimShot : bgShot
            visible: grimShot.status === Image.Ready || bgShot.hasContent
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
            saturation: -0.08
            brightness: -0.06
        }

        // 3) Wallpaper fallback when neither capture is available
        Image {
            anchors.fill: parent
            visible: grimShot.status !== Image.Ready && !bgShot.hasContent
            source: "file://" + root.wallpaperFallback
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        // Dark veil for text contrast — lighter than before so wallpaper
        // stays visible like the reference (was 0.38/0.52 washing to gray)
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.3
        }

        // subtle top/bottom vignette so status icons + pill read like reference
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0.18)
                }

                GradientStop {
                    position: 0.3
                    color: Qt.rgba(0, 0, 0, 0)
                }

                GradientStop {
                    position: 0.72
                    color: Qt.rgba(0, 0, 0, 0)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

            }

        }

    }

    // ── Center clock — upper third like reference ──
    ColumnLayout {
        id: clockCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.13
        spacing: 4
        opacity: 0

        transform: Translate {
            id: clockShift
            y: -22
        }

        Label {
            id: dateLabel

            property var now: new Date()

            Layout.alignment: Qt.AlignHCenter
            text: now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
            color: "#ffffff"
            opacity: 0.88
            font.family: "Adwaita Sans"
            font.pointSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering

            Timer {
                running: true
                interval: 15000
                repeat: true
                onTriggered: dateLabel.now = new Date()
            }

        }

        Label {
            id: timeLabel

            property var now: new Date()

            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(timeLabel.now, root.use12h ? "h:mm AP" : "HH:mm")
            color: "#f2f2f2"
            opacity: 0.96
            font.family: "Adwaita Sans"
            font.pointSize: 92
            font.weight: Font.Bold
            // tight tracking like reference 23:49
            font.letterSpacing: -4
            lineHeight: 0.95
            scale: 1
            renderType: Text.NativeRendering

            Timer {
                running: true
                interval: 1000
                repeat: true
                onTriggered: timeLabel.now = new Date()
            }

        }

    }

    // ── Battery pill — top-right status like the reference ──
    LockBattery {
        id: lockBattery

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 26
        anchors.rightMargin: 28
        opacity: 0
        shimmerOn: root.batteryShimmerOn
    }

    // ── Wifi — top-left status, mirrors the battery corner ──
    LockWifi {
        id: lockWifi

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 26
        anchors.leftMargin: 28
        opacity: 0
    }

    // per-char morphing dot, ported from polkit CharItem:
    // each keystroke pops in as a random shape, settles into a dot
    component DotItem: Item {
        id: dot

        required property int index
        property real nonAnimWidthScale: 1

        implicitHeight: dotList.implicitHeight

        ListView.onRemove: {
            initAnim.stop();
            removeAnim.start();
        }

        MaterialShape {
            id: dotShape

            anchors.centerIn: parent
            implicitSize: dotList.implicitHeight * 1.5
            shape: root.shapeQueue[dot.index % root.shapeQueue.length] ?? MaterialShape.Circle
            color: "#ffffff"

            SequentialAnimation {
                id: initAnim

                running: true

                ParallelAnimation {
                    NumberAnimation {
                        target: dotShape
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: dotShape
                        property: "scale"
                        from: 0
                        to: 1
                        duration: 220
                        easing.type: Easing.OutBack
                    }
                    NumberAnimation {
                        target: dot
                        property: "implicitWidth"
                        from: dotList.implicitHeight
                        to: dotList.implicitHeight * 1.3
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    PropertyAction {
                        target: dot
                        property: "nonAnimWidthScale"
                        value: 1.5
                    }
                }
                PauseAnimation {
                    duration: 170
                }
                PropertyAction {
                    target: dotShape
                    property: "shape"
                    value: MaterialShape.Circle
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: dotShape
                        property: "scale"
                        to: 2 / 3
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: dot
                        property: "implicitWidth"
                        to: dotList.implicitHeight
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    PropertyAction {
                        target: dot
                        property: "nonAnimWidthScale"
                        value: 1
                    }
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: dot
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: dotShape
                        property: "opacity"
                        to: 0
                        duration: 130
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: dotShape
                        property: "scale"
                        to: 0.5
                        duration: 130
                    }
                }
                PropertyAction {
                    target: dot
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }

    // ── Bottom auth cluster ──
    ColumnLayout {
        id: authCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        spacing: 9
        opacity: 0

        transform: Translate {
            id: authShift
            y: 26
        }

        // avatar — ClippingRectangle clips to radius (plain clip ignores it)
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 64
            height: 64

            ClippingRectangle {
                anchors.fill: parent
                radius: 32
                color: "#232323"

                Image {
                    id: faceImg

                    anchors.fill: parent
                    source: "file://" + root.facePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status !== Image.Error
                }

                Label {
                    id: fallback

                    anchors.centerIn: parent
                    visible: faceImg.status === Image.Error
                    text: ""
                    color: "#d8d8d8"
                    font.pointSize: 20
                }

            }

            Rectangle {
                anchors.fill: parent
                radius: 32
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
            }

        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            color: "#ffffff"
            opacity: 0.9
            font.family: "Adwaita Sans"
            font.pointSize: 10
            font.weight: Font.Medium
        }

        // password pill
        Rectangle {
            id: pillBg

            Layout.alignment: Qt.AlignHCenter
            // polkit-style: pill breathes wider while typing
            implicitWidth: context.currentText.length > 0 ? 268 : 208
            implicitHeight: 40
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.05, 0.7, 0.1, 1]
                }
            }
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            radius: 19
            color: context.showFailure ? Qt.rgba(1, 0.42, 0.42, 0.16) : Qt.rgba(1, 1, 1, 0.14)
            border.color: context.showFailure ? "#ff7a7a" : (passwordBox.activeFocus ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18))
            border.width: 1

            // polkit failShake: -12 / 10 / -6 / 0 with quad easings
            SequentialAnimation {
                id: shake

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: -12
                    duration: 60
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: 10
                    duration: 80
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: -6
                    duration: 80
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: pillBg
                    property: "x"
                    to: 0
                    duration: 80
                    easing.type: Easing.OutQuad
                }

            }

            Connections {
                function onShowFailureChanged() {
                    if (root.context.showFailure)
                        shake.start();

                }

                target: root.context
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                // lock icon — reddens on error like polkit
                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter

                    Label {
                        anchors.centerIn: parent
                        visible: !context.unlockInProgress
                        text: ""
                        color: root.fieldInError ? "#ff7a7a" : Qt.rgba(1, 1, 1, 0.6)
                        font.family: "JetBrainsMono NFM"
                        font.pointSize: 11

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }

                        }

                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        visible: context.unlockInProgress
                        running: visible
                        implicitWidth: 15
                        implicitHeight: 15
                    }

                }

                // middle: animated placeholder + morphing dots over invisible capture field
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Label {
                        id: pillPlaceholder

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        text: root.fieldInError ? "Incorrect password" : "Enter password"
                        color: root.fieldInError ? "#ff7a7a" : Qt.rgba(1, 1, 1, 0.5)
                        font.family: "Adwaita Sans"
                        font.pointSize: 9
                        opacity: context.currentText.length > 0 || context.unlockInProgress ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }

                        }

                    }

                    ListView {
                        id: dotList
                        // simple width math (avoids `as` cast on inline type — crashes qmllint)
                        readonly property int fullWidth: count * (implicitHeight + spacing)

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0
                        implicitWidth: fullWidth
                        implicitHeight: 12
                        orientation: Qt.Horizontal
                        spacing: 6
                        interactive: false
                        visible: !context.unlockInProgress

                        model: ScriptModel {
                            values: context.currentText.split("")
                        }

                        delegate: DotItem {
                        }

                    }

                    // invisible capture field — dots above render the state.
                    // opacity 0 (not just transparent text) so the caret
                    // can never blink through on any style.
                    TextField {
                        id: passwordBox

                        anchors.fill: parent
                        opacity: 0
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: ""
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        enabled: !context.unlockInProgress
                        focus: true
                        cursorVisible: false
                        Component.onCompleted: forceActiveFocus()
                        color: "transparent"
                        selectionColor: "transparent"
                        selectedTextColor: "transparent"
                        onTextChanged: {
                            if (context.currentText !== text)
                                context.currentText = text;

                        }
                        onAccepted: context.tryUnlock()

                        Connections {
                            function onCurrentTextChanged() {
                                if (passwordBox.text !== root.context.currentText)
                                    passwordBox.text = root.context.currentText;

                            }

                            target: root.context
                        }

                        background: Item {
                        }

                    }

                }

                // enter button — circle morphs into arrow while typing like polkit
                Item {
                    id: enterButton

                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    visible: !context.unlockInProgress

                    MaterialShape {
                        anchors.fill: parent
                        color: context.currentText.length > 0 ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, 0.22)
                        shape: context.currentText.length > 0 ? MaterialShape.Arrow : MaterialShape.Circle
                        scale: context.currentText.length === 0 ? 0.62 : enterMouse.pressed ? 0.6 : enterMouse.containsMouse ? 0.8 : 0.7
                        rotation: 90

                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                        MouseArea {
                            id: enterMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: context.currentText.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (context.currentText.length > 0)
                                    context.tryUnlock();

                            }
                        }

                    }

                }

            }

            // centered in the whole pill (not the middle row — siblings
            // hide/show while checking and would offset a row-centered label)
            // shimmer "Authenticating" (shadcn-style: dim base + bright sweep,
            // 2s linear loop). Self-contained: no shared imports allowed here.
            Item {
                id: authShimmer

                anchors.centerIn: parent
                width: authBase.implicitWidth
                height: authBase.implicitHeight
                opacity: context.unlockInProgress ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                }

                Label {
                    id: authBase

                    anchors.centerIn: parent
                    text: "Authenticating"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: "Adwaita Sans"
                    font.pointSize: 9
                    renderType: Text.NativeRendering
                }

                Item {
                    id: sheenMover

                    width: Math.max(60, authShimmer.width * 0.5)
                    height: authShimmer.height

                    readonly property real coreWidth: Math.max(24, authShimmer.width * 0.22)

                    Item {
                        anchors.fill: parent
                        clip: true

                        Label {
                            anchors.verticalCenter: authShimmer.verticalCenter
                            x: (authShimmer.width - implicitWidth) / 2 - sheenMover.x
                            width: implicitWidth
                            height: implicitHeight
                            text: "Authenticating"
                            color: "#ffffff"
                            opacity: 0.45
                            font.family: "Adwaita Sans"
                            font.pointSize: 9
                            renderType: Text.NativeRendering
                        }

                    }

                    Item {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: sheenMover.coreWidth
                        clip: true

                        Label {
                            anchors.verticalCenter: authShimmer.verticalCenter
                            x: (authShimmer.width - implicitWidth) / 2 - sheenMover.x - (sheenMover.width - sheenMover.coreWidth) / 2
                            width: implicitWidth
                            height: implicitHeight
                            text: "Authenticating"
                            color: "#ffffff"
                            font.family: "Adwaita Sans"
                            font.pointSize: 9
                            renderType: Text.NativeRendering
                        }

                    }

                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: authShimmer.visible
                        PauseAnimation {
                            duration: 250
                        }

                        NumberAnimation {
                            from: -sheenMover.width
                            to: authShimmer.width
                            duration: 2000
                            easing.type: Easing.Linear
                        }

                    }

                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }

            }

        }

    }

    // keep focus on password (Hyprland unfocuses on wake — Noctalia workaround)
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!passwordBox.activeFocus && !context.unlockInProgress)
                passwordBox.forceActiveFocus();

        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onEntered: {
            if (!passwordBox.activeFocus && !context.unlockInProgress)
                passwordBox.forceActiveFocus();

        }
    }

}
