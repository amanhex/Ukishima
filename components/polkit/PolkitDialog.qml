pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick.Effects

/**
 * midnight-shell's PolkitDialog (components/PolkitDialog.qml), ported
 * 1:1 against the vendored MsTheme/MsAnim/MsIcon/MsText stand-ins for
 * caelestia's Tokens/Colours/Anim/MaterialIcon/StyledText. Layout, message
 * splitting, shape-morph password dots, and open/close choreography are
 * unchanged. Only the focused monitor's instance activates.
 */
PanelWindow {
    id: root

    required property PolkitAgent agent
    required property var modelData
    property bool isFocused: false

    readonly property real centerScale: Math.max(0.8, Math.min(1, root.height / 1440))
    readonly property int centerWidth: root.modelData ? MsTheme.lockCenterWidth * centerScale : 0
    readonly property int passwordMaxWidth: centerWidth * 0.8

    readonly property string rawMessage: agent.flow ? agent.flow.message : ""
    readonly property var splitMessage: {
        let msg = rawMessage.trim();
        let cmd = "";

        let pkexecMatch = msg.match(/Authentication is needed to run `(.+?)' as the super user/);
        if (pkexecMatch) {
            cmd = pkexecMatch[1];
            msg = "Root privileges are required to execute:";
        } else if (msg.includes('\n')) {
            let parts = msg.split('\n').filter(s => s.trim().length > 0);
            if (parts.length > 1) {
                cmd = parts.pop().trim();
                msg = parts.join('\n').trim();
            }
        } else if (msg.includes(': ')) {
            let lastColonIdx = msg.lastIndexOf(': ');
            cmd = msg.substring(lastColonIdx + 2).trim();
            msg = msg.substring(0, lastColonIdx + 1).trim();
        } else {
            let backtickMatch = msg.match(/`(.+?)`/);
            if (backtickMatch) {
                cmd = backtickMatch[1];
                msg = msg.replace(backtickMatch[0], "").replace(/\s+/g, " ").trim();
            }
        }

        return {
            message: msg,
            command: cmd
        };
    }
    readonly property string mainMessage: splitMessage.message
    readonly property string commandText: splitMessage.command

    property string buffer: ""

    /**
     * Local failure state. The daemon's supplementaryMessage is preferred
     * when present, but quickshell does not reliably populate it on a
     * failed attempt, so authenticationFailed drives our own error line
     * (plus a shake) instead of failing silently.
     */
    property string authError: ""
    readonly property string daemonError: (agent.flow && agent.flow.supplementaryMessage) ? agent.flow.supplementaryMessage : ""
    readonly property bool daemonErrorIsError: agent.flow ? !!agent.flow.supplementaryIsError : false
    /**
     * Error state reflected inside the password pill itself (upstream only
     * shows the daemon line below the message): red border + red lock +
     * the placeholder swaps to a short error prompt via its animated swap.
     */
    readonly property bool fieldInError: authError.length > 0 || (daemonErrorIsError && daemonError.length > 0)
    readonly property string fieldErrorText: "Wrong password \u2014 try again."

    /**
     * Pending-submit state. Set on submit, cleared on failed / succeeded /
     * timeout / close. Drives the "Authenticating" indicator below the pill
     * and guards against double submits while the daemon decides.
     */
    property bool authenticating: false

    function submitPassword() {
        if (agent.flow && root.buffer && !root.authenticating) {
            agent.flow.submit(root.buffer);
            root.buffer = "";
            root.authError = "";
            root.authenticating = true;
            submitWatch.restart();
        }
    }

    //* No shapeQueue. The password dots used to cycle through 15 decorative
    //* MaterialShape silhouettes (Sunny, Gem, ClamShell…) before settling on a
    //* circle; they are plain circles now, same as the lockscreen's. See
    //* CharItem at the bottom of this file.

    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "ukishima-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool isActive: agent.isActive && agent.flow != null && isFocused
    visible: isActive || closeAnim.running

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    onIsActiveChanged: {
        if (isActive) {
            closeAnim.stop();
            root.authError = "";
            root.authenticating = false;
            openAnim.start();
            focusGuard.restart();
        } else {
            openAnim.stop();
            focusGuard.stop();
            submitWatch.stop();
            root.authenticating = false;
            closeAnim.start();
        }
    }

    /**
     * The field icon spins while authenticating; stopping the animation
     * freezes rotation mid-turn, so snap it back or the lock renders
     * upside down on the next prompt.
     */
    onAuthenticatingChanged: {
        if (!authenticating)
            fieldIcon.rotation = 0;
    }

    Connections {
        target: agent.flow
        enabled: agent.flow !== null

        function onAuthenticationFailed() {
            root.authenticating = false;
            if (!root.daemonError)
                root.authError = "Authentication failed, please try again.";
            failShake.start();
        }
        function onAuthenticationSucceeded() {
            root.authenticating = false;
            root.authError = "";
        }
        function onSupplementaryMessageChanged() {
            if (root.daemonError)
                root.authError = "";
        }
    }

    SequentialAnimation {
        id: failShake
        NumberAnimation {
            target: dialogContainer
            property: "x"
            to: -12
            duration: 60
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: dialogContainer
            property: "x"
            to: 10
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: dialogContainer
            property: "x"
            to: -6
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: dialogContainer
            property: "x"
            to: 0
            duration: 80
            easing.type: Easing.OutQuad
        }
    }

    /**
     * Watchdog: if the request is still pending 1.5s after submit with no
     * daemon message, the password was rejected. Guarantees feedback even
     * on agents that never emit authenticationFailed.
     */
    Timer {
        id: submitWatch

        interval: 1500
        onTriggered: {
            if (root.isActive && !root.daemonError) {
                root.authenticating = false;
                root.authError = "Authentication failed, please try again.";
                failShake.start();
            }
        }
    }

    /**
     * The pre-map forceActiveFocus in passwordRect's Connections can land
     * before the layer surface is mapped on slow activations, leaving keys
     * undelivered with no error. Re-assert until the field holds active
     * focus; an exclusive auth prompt owning focus while open is correct.
     */
    Timer {
        id: focusGuard

        interval: 120
        repeat: true
        onTriggered: {
            if (!root.isActive) {
                stop();
            } else if (!passwordRect.activeFocus) {
                passwordRect.forceActiveFocus();
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        SequentialAnimation {
            ParallelAnimation {
                MsAnim {
                    target: dialogContainer
                    property: "opacity"
                    to: 1
                    duration: MsTheme.durSmall
                }
                MsAnim {
                    target: dialogContainer
                    property: "scale"
                    to: 1
                    type: MsAnim.Emphasized
                    duration: 400
                }
            }
            // Delegate size expansion to Behaviors so they constantly evaluate layout recalculations
            PropertyAction {
                target: dialogContainer
                property: "isExpanded"
                value: true
            }
            ParallelAnimation {
                MsAnim {
                    target: lockIcon
                    property: "scale"
                    to: 0
                    type: MsAnim.Emphasized
                    duration: 400
                }
                MsAnim {
                    type: MsAnim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                    duration: 250
                }
                MsAnim {
                    type: MsAnim.DefaultEffects
                    target: dialogContent
                    property: "opacity"
                    to: 1
                    duration: 500
                }
                MsAnim {
                    target: dialogContent
                    property: "scale"
                    to: 1
                    type: MsAnim.Emphasized
                    duration: 500
                }
                MsAnim {
                    target: dialogBg
                    property: "radius"
                    to: MsTheme.roundingLarge
                    duration: 500
                }
            }
        }
    }

    TextMetrics {
        id: nonAnimPlaceholder

        text: root.authenticating ? "Authenticating" : root.fieldInError ? root.fieldErrorText : "Enter your password"
        font.family: MsTheme.bodyFamily
        font.pointSize: MsTheme.bodyMedium * centerScale
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            // Trigger collapse logic via the Behavior state
            PropertyAction {
                target: dialogContainer
                property: "isExpanded"
                value: false
            }
            MsAnim {
                target: dialogBg
                property: "radius"
                to: dialogContainer.initialRadius
            }
            MsAnim {
                target: dialogContent
                property: "scale"
                to: 0
            }
            MsAnim {
                target: dialogContent
                property: "opacity"
                to: 0
                type: MsAnim.StandardSmall
            }
            MsAnim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: MsAnim.StandardLarge
            }
            MsAnim {
                target: lockIcon
                property: "scale"
                to: 1
                type: MsAnim.StandardLarge
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: MsTheme.durSmall
                }
                MsAnim {
                    target: dialogContainer
                    property: "opacity"
                    to: 0
                    type: MsAnim.Standard
                }
                PropertyAction {
                    target: dialogContainer
                    property: "scale"
                    value: 0
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Item {
        id: dialogContainer

        property bool isExpanded: false

        readonly property int iconSize: lockIcon.implicitHeight + (root.modelData ? MsTheme.paddingLarge * 4 : 0)
        readonly property int initialRadius: root.modelData ? iconSize / 4 * MsTheme.scale : 0

        property int targetWidth: Math.max(420, root.passwordMaxWidth + MsTheme.paddingExtraLarge * 2)
        property int targetHeight: dialogContent.implicitHeight + (MsTheme.paddingLarge * 2)

        anchors.centerIn: parent
        implicitWidth: isExpanded ? targetWidth : iconSize
        implicitHeight: isExpanded ? targetHeight : iconSize
        scale: 0

        // This prevents the snapshotting issue by persistently interpolating dynamically updating bindings
        Behavior on implicitWidth {
            MsAnim {
                type: MsAnim.Emphasized
                duration: 500
            }
        }
        Behavior on implicitHeight {
            MsAnim {
                type: MsAnim.Emphasized
                duration: 500
            }
        }

        Rectangle {
            id: dialogBg

            anchors.fill: parent
            radius: dialogContainer.initialRadius
            color: MsTheme.layer(MsTheme.m3surface, 0)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(MsTheme.m3shadow, 0.7)
            }
        }

        MsIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "shield_person"
            fill: 1
            iconSize: MsTheme.iconExtraLarge * 2
            iconWeight: Font.Medium
            color: MsTheme.m3secondary
        }

        ColumnLayout {
            id: dialogContent

            width: dialogContainer.targetWidth - MsTheme.paddingLarge * 2
            anchors.centerIn: parent

            opacity: 0
            scale: 0
            spacing: MsTheme.spacingLarge

            // Title Container
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: titleLayout.implicitHeight + MsTheme.paddingLarge * 2
                color: MsTheme.layer(MsTheme.m3surfaceContainer, 1)
                radius: MsTheme.roundingLarge

                ColumnLayout {
                    id: titleLayout

                    anchors.fill: parent
                    anchors.margins: MsTheme.paddingLarge
                    spacing: 0

                    MsText {
                        Layout.fillWidth: true
                        text: "Authentication Required"
                        font.family: MsTheme.bodyFamily
                        font.pointSize: MsTheme.titleLarge
                        font.weight: Font.Medium
                        color: MsTheme.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Message and Command
            Column {
                Layout.fillWidth: true
                spacing: MsTheme.spacingMedium

                MsText {
                    width: parent.width
                    text: root.mainMessage
                    font.family: MsTheme.bodyFamily
                    font.pointSize: MsTheme.bodyMedium
                    color: MsTheme.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.commandText.length > 0
                    width: Math.min(commandLabel.implicitWidth + MsTheme.paddingLarge * 2, parent.width)
                    implicitHeight: commandLabel.implicitHeight + MsTheme.paddingSmall * 2
                    color: MsTheme.layer(MsTheme.m3surfaceContainerHigh, 1)
                    radius: MsTheme.roundingSmall

                    MsText {
                        id: commandLabel

                        anchors.fill: parent
                        anchors.margins: MsTheme.paddingSmall
                        anchors.leftMargin: MsTheme.paddingLarge
                        anchors.rightMargin: MsTheme.paddingLarge
                        text: root.commandText
                        font.family: MsTheme.monoFamily
                        font.pointSize: MsTheme.monoMedium
                        color: MsTheme.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                    }
                }

                MsText {
                    width: parent.width
                    text: root.daemonError
                    font.family: MsTheme.bodyFamily
                    font.pointSize: MsTheme.bodySmall
                    color: root.daemonErrorIsError ? MsTheme.m3error : MsTheme.m3onSurfaceVariant
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                id: passwordRect

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: {
                    const emptyW = nonAnimPlaceholder.width + iconWrapper.implicitWidth + enterButton.implicitWidth + passwordInputLayout.spacing * 2 + MsTheme.paddingMedium * 2;
                    return root.buffer.length > 0 ? root.passwordMaxWidth : Math.min(root.passwordMaxWidth, emptyW);
                }
                implicitHeight: passwordInputLayout.implicitHeight + MsTheme.paddingSmall
                color: MsTheme.layer(MsTheme.m3surfaceContainer, 1)
                radius: MsTheme.roundingFull
                border.color: root.fieldInError ? MsTheme.m3error : "transparent"
                border.width: 1

                focus: true

                Behavior on implicitWidth {
                    MsAnim {
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: MsTheme.durFastEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: MsTheme.curveFastEffects
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: passwordRect.forceActiveFocus()
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        root.submitPassword();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace) {
                        submitWatch.stop();
                        if (root.buffer.length > 0) {
                            root.buffer = root.buffer.slice(0, -1);
                        }
                        if (root.buffer.length === 0) {
                            placeholder.animate = true;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        if (agent.flow) {
                            agent.flow.cancelAuthenticationRequest();
                        }
                        root.buffer = "";
                        event.accepted = true;
                    } else if (event.text.length > 0) {
                        root.buffer += event.text;
                        root.authError = "";
                        submitWatch.stop();
                        event.accepted = true;
                    }
                }

                Connections {
                    function onIsActiveChanged() {
                        if (agent.isActive) {
                            root.buffer = "";
                            passwordRect.forceActiveFocus();
                        }
                    }

                    target: agent
                }

                RowLayout {
                    id: passwordInputLayout

                    anchors.fill: parent
                    anchors.margins: MsTheme.paddingExtraSmall
                    spacing: MsTheme.spacingMedium

                    Item {
                        id: iconWrapper

                        Layout.fillHeight: true
                        implicitWidth: height

                        MsIcon {
                            id: fieldIcon

                            anchors.centerIn: parent
                            text: root.authenticating ? "progress_activity" : "lock"
                            color: root.authenticating ? MsTheme.m3primary : root.fieldInError ? MsTheme.m3error : MsTheme.m3onSurfaceVariant
                            iconSize: MsTheme.iconMedium * centerScale

                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.authenticating
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        MsText {
                            id: placeholder

                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            text: root.fieldInError ? root.fieldErrorText : "Enter your password"
                            animate: true
                            color: root.fieldInError ? MsTheme.m3error : MsTheme.m3outline
                            font.family: MsTheme.bodyFamily
                            font.pointSize: MsTheme.bodyMedium * centerScale
                            opacity: root.buffer.length > 0 || root.authenticating ? 0 : 1

                            Behavior on opacity {
                                MsAnim {
                                    type: MsAnim.DefaultEffects
                                }
                            }
                        }

                        /**
                         * Shimmer "Authenticating" (shadcn-style: muted base
                         * text with a bright highlight sweeping across in a
                         * 2s linear loop). QML Text has no
                         * background-clip:text, so the sweep is a clipped
                         * bright copy sliding over the dim base: a wide faint
                         * halo plus a narrow bright core for soft edges.
                         */
                        Item {
                            id: shimmerWrap

                            anchors.centerIn: parent
                            width: shimmerBase.implicitWidth
                            height: shimmerBase.implicitHeight
                            visible: root.authenticating && root.buffer.length === 0

                            MsText {
                                id: shimmerBase

                                anchors.centerIn: parent
                                text: "Authenticating"
                                color: MsTheme.m3outline
                                font.family: MsTheme.bodyFamily
                                font.pointSize: MsTheme.bodyMedium * centerScale
                            }

                            Item {
                                id: sheenMover

                                width: Math.max(90 * centerScale, shimmerWrap.width * 0.5)
                                height: shimmerWrap.height

                                readonly property real coreWidth: Math.max(34 * centerScale, shimmerWrap.width * 0.22)

                                Item {
                                    anchors.fill: parent
                                    clip: true

                                    MsText {
                                        anchors.verticalCenter: shimmerWrap.verticalCenter
                                        x: (shimmerWrap.width - implicitWidth) / 2 - sheenMover.x
                                        width: implicitWidth
                                        height: implicitHeight
                                        text: "Authenticating"
                                        color: MsTheme.m3onSurface
                                        opacity: 0.45
                                        font.family: MsTheme.bodyFamily
                                        font.pointSize: MsTheme.bodyMedium * centerScale
                                    }
                                }

                                Item {
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: sheenMover.coreWidth
                                    clip: true

                                    MsText {
                                        anchors.verticalCenter: shimmerWrap.verticalCenter
                                        x: (shimmerWrap.width - implicitWidth) / 2 - sheenMover.x - (sheenMover.width - sheenMover.coreWidth) / 2
                                        width: implicitWidth
                                        height: implicitHeight
                                        text: "Authenticating"
                                        color: MsTheme.m3onSurface
                                        font.family: MsTheme.bodyFamily
                                        font.pointSize: MsTheme.bodyMedium * centerScale
                                    }
                                }

                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    running: shimmerWrap.visible
                                    PauseAnimation {
                                        duration: 250
                                    }
                                    NumberAnimation {
                                        from: -sheenMover.width
                                        to: shimmerWrap.width
                                        duration: 2000
                                        easing.type: Easing.Linear
                                    }
                                }
                            }
                        }

                        ListView {
                            id: charList

                            //* Plain arithmetic: n dots plus n-1 gaps. This used
                            //* to walk every delegate and add its
                            //* nonAnimWidthScale, because each dot animated its
                            //* own implicitWidth and the row had to be
                            //* re-measured mid-animation. Dots no longer animate
                            //* their width, so the row can just be counted.
                            readonly property int fullWidth: count === 0 ? 0
                                    : count * implicitHeight + (count - 1) * spacing

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0

                            implicitWidth: fullWidth
                            implicitHeight: MsTheme.bodyMedium

                            orientation: Qt.Horizontal
                            spacing: MsTheme.spacingSmall
                            interactive: false

                            model: ScriptModel {
                                values: root.buffer.split("")
                            }

                            delegate: CharItem {
                            }

                            //* Kept, unlike the lockscreen's dot list: the row
                            //* still grows smoothly as characters land. This is
                            //* safe now precisely because the delegates no
                            //* longer animate a layout property — that clash is
                            //* what bindImWidth() used to work around.
                            Behavior on implicitWidth {
                                MsAnim {
                                }
                            }
                        }
                    }

                    Item {
                        id: enterButton

                        implicitWidth: implicitHeight
                        //* Was derived from the Material Symbols arrow glyph's
                        //* own implicitHeight. It is a fixed size now that the
                        //* glyph is a Nerd Font codepoint, and this lands on
                        //* almost exactly the old 30px.
                        implicitHeight: MsTheme.bodyMedium * 2

                        //* The lockscreen's enter button, from
                        //* lockscreen/LockSurface.qml: a plain circle whose fill
                        //* inverts against a return glyph. This replaces a
                        //* MaterialShape that was either a circle or a rotated
                        //* Arrow, which was the second of the two M3Shapes
                        //* usages in this file.
                        Rectangle {
                            id: enterCircle

                            anchors.fill: parent
                            radius: width / 2
                            color: root.buffer ? MsTheme.m3primary : MsTheme.layer(MsTheme.m3surfaceContainerHigh, 2)
                            scale: !root.buffer ? 1 : enterMouse.pressed ? 0.6 : enterMouse.containsMouse ? 0.8 : 0.7

                            Behavior on scale {
                                MsAnim {
                                    type: MsAnim.FastSpatial
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: MsTheme.durSlowEffects
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: MsTheme.curveSlowEffects
                                }
                            }

                            //* U+E862, nf-fa-return — the same glyph the
                            //* lockscreen puts in this exact spot. It inverts
                            //* with the fill: the circle goes from a dim
                            //* #242424 to the #e0563b primary, so the glyph has
                            //* to go light to dark.
                            //*
                            //* CaskaydiaCove NF is already MsTheme.monoFamily
                            //* and is verified to carry U+E862, so this costs
                            //* no new font dependency. The lockscreen asks for
                            //* "JetBrainsMono NFM", which is not installed
                            //* under that exact name here.
                            MsText {
                                anchors.centerIn: parent
                                text: "\ue862"
                                font.family: MsTheme.monoFamily
                                font.pointSize: MsTheme.bodyMedium
                                color: root.buffer ? MsTheme.m3surfaceContainer : MsTheme.m3onSurfaceVariant

                                Behavior on color {
                                    ColorAnimation {
                                        duration: MsTheme.durSlowEffects
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: MsTheme.curveSlowEffects
                                    }
                                }
                            }

                            MouseArea {
                                id: enterMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.buffer ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.submitPassword();
                            }
                        }
                    }
                }
            }
        }
    }

    //* One password dot: the lockscreen's dot (lockscreen/LockSurface.qml ->
    //* DotItem) brought over as-is in spirit — a plain rounded Rectangle and a
    //* single short opacity+scale ramp per keystroke.
    //*
    //* It was a MaterialShape cycling through 15 decorative silhouettes before
    //* settling on a circle, and that made one keystroke 570ms: an OutBack
    //* spring overshot to 1.085, the dot then sat frozen for 180ms on a bare
    //* PauseAnimation, and it finally shrank to 2/3 and stayed there, with its
    //* width animating 15.6 -> 12.0 on top. Type at speed and several dots sit
    //* mid-cycle at three different scales, older ones visibly smaller.
    //*
    //* The lockscreen had already worked this out: opacity 0 -> 1 and scale
    //* 0.6 -> 1, no overshoot, no pause, and no second motion on the width.
    //* Dropping the width animation is also what let the ListView below drop
    //* its nonAnimWidthScale/bindImWidth machinery — it can now just measure.
    component CharItem: Item {
        id: char

        required property int index

        //* Static, and 1.0 * implicitHeight, so row spacing is unchanged.
        //* Animating a layout property is what used to force the
        //* nonAnimWidthScale bookkeeping in the ListView.
        implicitWidth: charList.implicitHeight
        implicitHeight: charList.implicitHeight

        ListView.onRemove: {
            initAnim.stop();
            removeAnim.start();
        }

        Rectangle {
            id: charRect

            anchors.centerIn: parent
            //* 0.8 * implicitHeight, which is what the old animation settled
            //* on: 1.2 * 2/3 == 0.8, so a resting dot is the same size it
            //* always was. Any other ratio would silently resize every dot.
            width: charList.implicitHeight * 0.8
            height: width
            radius: width / 2
            color: MsTheme.m3onSurface
            opacity: 0
            scale: 0.6

            ParallelAnimation {
                id: initAnim

                running: true

                MsAnim {
                    target: charRect
                    property: "opacity"
                    from: 0
                    to: 1
                    type: MsAnim.FastEffects
                }
                MsAnim {
                    target: charRect
                    property: "scale"
                    from: 0.6
                    to: 1
                    type: MsAnim.FastEffects
                }
            }

            SequentialAnimation {
                id: removeAnim

                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: true
                }
                ParallelAnimation {
                    MsAnim {
                        type: MsAnim.FastEffects
                        target: charRect
                        property: "opacity"
                        to: 0
                    }
                    MsAnim {
                        target: charRect
                        property: "scale"
                        to: 0.5
                    }
                }
                PropertyAction {
                    target: char
                    property: "ListView.delayRemove"
                    value: false
                }
            }
        }
    }
}
