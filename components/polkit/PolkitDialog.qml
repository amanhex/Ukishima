pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick.Effects

/**
 * midnight-shell's PolkitDialog (components/PolkitDialog.qml), ported
 * 1:1 against the vendored PolTheme/PolAnim/PolIcon/PolText stand-ins for
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
    readonly property int centerWidth: root.modelData ? PolTheme.lockCenterWidth * centerScale : 0
    readonly property int passwordMaxWidth: centerWidth * 0.8
    //* Ceiling for the password field itself, which is much narrower than the
    //* card it sits in. Deliberately not passwordMaxWidth: that also drives
    //* dialogContainer.targetWidth, so lowering it would shrink the whole
    //* dialog rather than just the input.
    readonly property int passwordFieldMaxWidth: centerWidth * 0.56

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
                PolAnim {
                    target: dialogContainer
                    property: "opacity"
                    to: 1
                    duration: PolTheme.durSmall
                }
                PolAnim {
                    target: dialogContainer
                    property: "scale"
                    to: 1
                    type: PolAnim.Emphasized
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
                PolAnim {
                    target: lockIcon
                    property: "scale"
                    to: 0
                    type: PolAnim.Emphasized
                    duration: 400
                }
                PolAnim {
                    type: PolAnim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                    duration: 250
                }
                PolAnim {
                    type: PolAnim.DefaultEffects
                    target: dialogContent
                    property: "opacity"
                    to: 1
                    duration: 500
                }
                PolAnim {
                    target: dialogContent
                    property: "scale"
                    to: 1
                    type: PolAnim.Emphasized
                    duration: 500
                }
                PolAnim {
                    target: dialogBg
                    property: "radius"
                    to: PolTheme.roundingLarge
                    duration: 500
                }
            }
        }
    }

    TextMetrics {
        id: nonAnimPlaceholder

        text: root.authenticating ? "Authenticating" : root.fieldInError ? root.fieldErrorText : "Enter your password"
        font.family: PolTheme.bodyFamily
        font.pointSize: PolTheme.bodyMedium * centerScale
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
            PolAnim {
                target: dialogBg
                property: "radius"
                to: dialogContainer.initialRadius
            }
            PolAnim {
                target: dialogContent
                property: "scale"
                to: 0
            }
            PolAnim {
                target: dialogContent
                property: "opacity"
                to: 0
                type: PolAnim.StandardSmall
            }
            PolAnim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: PolAnim.StandardLarge
            }
            PolAnim {
                target: lockIcon
                property: "scale"
                to: 1
                type: PolAnim.StandardLarge
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: PolTheme.durSmall
                }
                PolAnim {
                    target: dialogContainer
                    property: "opacity"
                    to: 0
                    type: PolAnim.Standard
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

        readonly property int iconSize: lockIcon.implicitHeight + (root.modelData ? PolTheme.paddingLarge * 4 : 0)
        readonly property int initialRadius: root.modelData ? iconSize / 4 * PolTheme.scale : 0

        property int targetWidth: Math.max(420, root.passwordMaxWidth + PolTheme.paddingExtraLarge * 2)
        property int targetHeight: dialogContent.implicitHeight + (PolTheme.paddingLarge * 2)

        anchors.centerIn: parent
        implicitWidth: isExpanded ? targetWidth : iconSize
        implicitHeight: isExpanded ? targetHeight : iconSize
        scale: 0

        // This prevents the snapshotting issue by persistently interpolating dynamically updating bindings
        Behavior on implicitWidth {
            PolAnim {
                type: PolAnim.Emphasized
                duration: 500
            }
        }
        Behavior on implicitHeight {
            PolAnim {
                type: PolAnim.Emphasized
                duration: 500
            }
        }

        Rectangle {
            id: dialogBg

            anchors.fill: parent
            radius: dialogContainer.initialRadius
            color: PolTheme.layer(PolTheme.m3surface, 0)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(PolTheme.m3shadow, 0.7)
            }
        }

        PolIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "shield_person"
            fill: 1
            iconSize: PolTheme.iconExtraLarge * 2
            iconWeight: Font.Medium
            color: PolTheme.m3secondary
        }

        ColumnLayout {
            id: dialogContent

            width: dialogContainer.targetWidth - PolTheme.paddingLarge * 2
            anchors.centerIn: parent

            opacity: 0
            scale: 0
            spacing: PolTheme.spacingLarge

            // Title Container
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: titleLayout.implicitHeight + PolTheme.paddingLarge * 2
                color: PolTheme.layer(PolTheme.m3surfaceContainer, 1)
                radius: PolTheme.roundingLarge

                ColumnLayout {
                    id: titleLayout

                    anchors.fill: parent
                    anchors.margins: PolTheme.paddingLarge
                    spacing: 0

                    PolText {
                        Layout.fillWidth: true
                        text: "Authentication Required"
                        font.family: PolTheme.bodyFamily
                        font.pointSize: PolTheme.titleLarge
                        font.weight: Font.Medium
                        color: PolTheme.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Message and Command
            Column {
                Layout.fillWidth: true
                spacing: PolTheme.spacingMedium

                PolText {
                    width: parent.width
                    text: root.mainMessage
                    font.family: PolTheme.bodyFamily
                    font.pointSize: PolTheme.bodyMedium
                    color: PolTheme.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.commandText.length > 0
                    width: Math.min(commandLabel.implicitWidth + PolTheme.paddingLarge * 2, parent.width)
                    implicitHeight: commandLabel.implicitHeight + PolTheme.paddingSmall * 2
                    color: PolTheme.layer(PolTheme.m3surfaceContainerHigh, 1)
                    radius: PolTheme.roundingSmall

                    PolText {
                        id: commandLabel

                        anchors.fill: parent
                        anchors.margins: PolTheme.paddingSmall
                        anchors.leftMargin: PolTheme.paddingLarge
                        anchors.rightMargin: PolTheme.paddingLarge
                        text: root.commandText
                        font.family: PolTheme.monoFamily
                        font.pointSize: PolTheme.monoMedium
                        color: PolTheme.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                    }
                }

                PolText {
                    width: parent.width
                    text: root.daemonError
                    font.family: PolTheme.bodyFamily
                    font.pointSize: PolTheme.bodySmall
                    color: root.daemonErrorIsError ? PolTheme.m3error : PolTheme.m3onSurfaceVariant
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                id: passwordRect

                Layout.alignment: Qt.AlignHCenter
                //* The row's chrome: everything in the field except the text.
                //*
                //* iconWrapper's own implicitWidth is `height` under
                //* Layout.fillHeight, so it is order-dependent — measured
                //* anywhere between 20 and 44 depending on when the binding is
                //* evaluated. This budgets the top of that range on purpose.
                //* Over-reserving costs a few px of width; under-reserving
                //* clips the placeholder, which is the failure that actually
                //* shows: at a flat 208 the field cut "Enter your password" to
                //* "your pas".
                readonly property int chrome: PolTheme.paddingExtraSmall * 2
                        + PolTheme.spacingMedium * 2
                        + PolTheme.bodyMedium * 2   // the 28px enter button
                        + 44                        // the icon cell, upper bound
                //* Idle is floored by the placeholder so it can never clip;
                //* typing widens to the lockscreen's 268 (lockscreen/
                //* LockSurface.qml), which is also where a dot row of any
                //* reasonable length stops needing to scroll.
                implicitWidth: Math.min(root.passwordFieldMaxWidth,
                        Math.max(root.buffer.length > 0 ? 268 : 0,
                                nonAnimPlaceholder.width + chrome))
                //* Was paddingSmall, giving a 36px field — the enter button's own
                //* 28px plus 8. paddingLarge + paddingSmall is 24, so the field
                //* is 52px: tall enough to aim at, without turning a text input
                //* into a slab.
                implicitHeight: passwordInputLayout.implicitHeight + PolTheme.paddingLarge + PolTheme.paddingSmall
                color: PolTheme.layer(PolTheme.m3surfaceContainer, 1)
                radius: PolTheme.roundingFull
                border.color: root.fieldInError ? PolTheme.m3error : "transparent"
                border.width: 1

                focus: true

                Behavior on implicitWidth {
                    PolAnim {
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: PolTheme.durFastEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: PolTheme.curveFastEffects
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
                    anchors.margins: PolTheme.paddingExtraSmall
                    spacing: PolTheme.spacingMedium

                    Item {
                        id: iconWrapper

                        Layout.fillHeight: true
                        implicitWidth: height

                        PolIcon {
                            id: fieldIcon

                            anchors.centerIn: parent
                            text: root.authenticating ? "progress_activity" : "lock"
                            color: root.authenticating ? PolTheme.m3primary : root.fieldInError ? PolTheme.m3error : PolTheme.m3onSurfaceVariant
                            iconSize: PolTheme.iconMedium * centerScale

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

                        PolText {
                            id: placeholder

                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            text: root.fieldInError ? root.fieldErrorText : "Enter your password"
                            animate: true
                            color: root.fieldInError ? PolTheme.m3error : PolTheme.m3outline
                            font.family: PolTheme.bodyFamily
                            font.pointSize: PolTheme.bodyMedium * centerScale
                            opacity: root.buffer.length > 0 || root.authenticating ? 0 : 1

                            Behavior on opacity {
                                PolAnim {
                                    type: PolAnim.DefaultEffects
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

                            PolText {
                                id: shimmerBase

                                anchors.centerIn: parent
                                text: "Authenticating"
                                color: PolTheme.m3outline
                                font.family: PolTheme.bodyFamily
                                font.pointSize: PolTheme.bodyMedium * centerScale
                            }

                            Item {
                                id: sheenMover

                                width: Math.max(90 * centerScale, shimmerWrap.width * 0.5)
                                height: shimmerWrap.height

                                readonly property real coreWidth: Math.max(34 * centerScale, shimmerWrap.width * 0.22)

                                Item {
                                    anchors.fill: parent
                                    clip: true

                                    PolText {
                                        anchors.verticalCenter: shimmerWrap.verticalCenter
                                        x: (shimmerWrap.width - implicitWidth) / 2 - sheenMover.x
                                        width: implicitWidth
                                        height: implicitHeight
                                        text: "Authenticating"
                                        color: PolTheme.m3onSurface
                                        opacity: 0.45
                                        font.family: PolTheme.bodyFamily
                                        font.pointSize: PolTheme.bodyMedium * centerScale
                                    }
                                }

                                Item {
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: sheenMover.coreWidth
                                    clip: true

                                    PolText {
                                        anchors.verticalCenter: shimmerWrap.verticalCenter
                                        x: (shimmerWrap.width - implicitWidth) / 2 - sheenMover.x - (sheenMover.width - sheenMover.coreWidth) / 2
                                        width: implicitWidth
                                        height: implicitHeight
                                        text: "Authenticating"
                                        color: PolTheme.m3onSurface
                                        font.family: PolTheme.bodyFamily
                                        font.pointSize: PolTheme.bodyMedium * centerScale
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

                            //* The drawn size of one dot, and the width of the
                            //* cell that holds it. These were the same number
                            //* before — the cell was charList.implicitHeight (14)
                            //* around an 11.2px dot — which wasted 2.8px per
                            //* character. Eight characters then needed 168px in a
                            //* 164px cell, and because the middle Item clips, the
                            //* first dot lost its left edge and rendered as a
                            //* sliver. The cell is now exactly the dot.
                            readonly property real dotSize: implicitHeight * 0.8
                            readonly property real fullWidth: count === 0 ? 0
                                    : count * dotSize + (count - 1) * spacing

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: implicitWidth > parent.width ? -(implicitWidth - parent.width) / 2 : 0

                            implicitWidth: fullWidth
                            implicitHeight: PolTheme.bodyMedium

                            orientation: Qt.Horizontal
                            spacing: PolTheme.spacingSmall
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
                                PolAnim {
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
                        implicitHeight: PolTheme.bodyMedium * 2

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
                            color: root.buffer ? PolTheme.m3primary : PolTheme.layer(PolTheme.m3surfaceContainerHigh, 2)
                            scale: !root.buffer ? 1 : enterMouse.pressed ? 0.6 : enterMouse.containsMouse ? 0.8 : 0.7

                            Behavior on scale {
                                PolAnim {
                                    type: PolAnim.FastSpatial
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: PolTheme.durSlowEffects
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: PolTheme.curveSlowEffects
                                }
                            }

                            //* Material Symbols "keyboard_return" — the
                            //* hooked return arrow.
                            //*
                            //* This was a Nerd Font codepoint, U+E862, on the
                            //* assumption it was nf-fa-return. It is not: in
                            //* CaskaydiaCove NF that codepoint is a ghost face,
                            //* so the button drew a small white ghost instead
                            //* of an arrow. Confirmed by rendering the
                            //* candidates side by side.
                            //*
                            //* The ligature form is used instead because
                            //* Material Symbols Rounded is already
                            //* PolTheme.iconFamily and is what PolIcon has always
                            //* used in this file, so it needs no extra
                            //* fontconfig entry and cannot silently fall back
                            //* to some other font the way a raw codepoint in an
                            //* uninstalled family does.
                            PolIcon {
                                anchors.centerIn: parent
                                //* Optical centring, measured rather than
                                //* guessed. Material Symbols draws its glyphs
                                //* in the upper part of a tall em box — it
                                //* reserves room for descenders — so anchoring
                                //* the Text box to the centre leaves the ink
                                //* above it. On the real 28px button the ink
                                //* bounding box measured 2.0px high and its
                                //* visual mass 1.1px left / 2.15px high, the
                                //* same to a tenth of a pixel across eight
                                //* renderings. Hence +1 / +2 here.
                                //*
                                //* Both offsets are constant because neither
                                //* the 28px button nor the 18px glyph is
                                //* scaled by centerScale.
                                anchors.horizontalCenterOffset: 1
                                anchors.verticalCenterOffset: 2
                                text: "keyboard_return"
                                color: root.buffer ? PolTheme.m3surfaceContainer : PolTheme.m3onSurfaceVariant

                                Behavior on color {
                                    ColorAnimation {
                                        duration: PolTheme.durSlowEffects
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: PolTheme.curveSlowEffects
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

        //* Static, and exactly one dot wide, so the cell adds no dead space
        //* around the dot. Animating a layout property is what used to force
        //* the nonAnimWidthScale bookkeeping in the ListView.
        implicitWidth: charList.dotSize
        implicitHeight: charList.implicitHeight

        ListView.onRemove: {
            initAnim.stop();
            removeAnim.start();
        }

        Rectangle {
            id: charRect

            anchors.centerIn: parent
            //* Exactly the cell width, so a row of these is charList.dotSize
            //* per dot with no slack to accumulate into a clipped first dot.
            width: charList.dotSize
            height: width
            radius: width / 2
            color: PolTheme.m3onSurface
            opacity: 0
            scale: 0.6

            ParallelAnimation {
                id: initAnim

                running: true

                PolAnim {
                    target: charRect
                    property: "opacity"
                    from: 0
                    to: 1
                    type: PolAnim.FastEffects
                }
                PolAnim {
                    target: charRect
                    property: "scale"
                    from: 0.6
                    to: 1
                    type: PolAnim.FastEffects
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
                    PolAnim {
                        type: PolAnim.FastEffects
                        target: charRect
                        property: "opacity"
                        to: 0
                    }
                    PolAnim {
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
