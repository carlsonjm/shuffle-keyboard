pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.VirtualKeyboard
import org.kde.kirigami as Kirigami
import QtQuick.VirtualKeyboard.Settings

import org.kde.plasma.keyboard

InputPanelWindow {
    id: root

    // As tall as the card and one row more, for the accents that rise above
    // the top row, and no taller: a window the size of the screen, even a
    // transparent one, is composited whole on every frame the keys are up.
    // The card slides inside it, and the compositor places the panel by its
    // input region either way.
    width: Screen.width
    height: root.panelHeight + Math.ceil(root.rowHeight)
    color: "transparent"

    property bool precisionHeld: false
    // The keyboard is a card: Kadunce's gutter at either side and nowhere
    // else, rounded as a card is where it stands free, flush with the screen's
    // bottom edge and lying over the window above it. Its top strip is kept
    // clear for predictions, which come after 1.0; the Hide key, not a
    // handle, puts the keys away.
    readonly property real sideGutter: 10
    readonly property real cardRadius: 8
    readonly property real topStrip: 26

    // The card is 44% of the screen's height, always: Shuffle's window roll
    // gives the Active card its room, so shorter keys would win nothing back.
    // The four rows set the key height, and a character key is as wide as it
    // is tall unless a row of them would not fit inside the card, when they
    // all narrow together.
    readonly property int heightPercent: 44
    readonly property real keyGap: Math.max(5, Math.min(10, root.width * 0.0062))
    readonly property real outerGap: Math.max(6, Math.min(12, root.width * 0.007))
    readonly property real panelHeight: Math.round(Screen.height * heightPercent / 100)
    readonly property real rowHeight: (panelHeight - root.topStrip - root.keyGap * 3 - root.outerGap) / 4
    readonly property real keyUnitWidth: Math.max(1, Math.min(rowHeight,
        (root.width - root.sideGutter * 2 - root.outerGap * 2 + root.keyGap) / keyField.totalUnits - root.keyGap))
    property int probeIndex: 0
    property int probeShortcutStep: 0
    property bool probeArmed: shuffleProbeDelay <= 0
    property bool probeTypingComplete: false

    readonly property bool precisionActive: precisionHeld
    readonly property int probeRepeat: shuffleProbeRepeat > 0 ? shuffleProbeRepeat : 1
    readonly property int probeLength: shuffleProbeText.length * probeRepeat

    // The keys that are on screen, so what they cover grows as they rise and
    // shrinks as they leave, and a card makes room at the pace the keys take
    // it rather than all at once. The keys rise only once the dock has let
    // its reservation go, so the compositor placing the panel again as this
    // changes finds the same bottom edge every time. Never quite empty, since
    // an empty region is no panel at all.
    interactiveRegion: Qt.rect(panel.x, root.height - panel.height + Math.min(root.carry, panel.height - 2),
                               panel.width, Math.max(2, panel.height - root.carry))

    // The arrival. The keys start below the screen's edge and rise from it on
    // their own. They wait until the dock has left and given up its room, so
    // they never rise into the dock's room while it is there, and the
    // compositor has already placed them at the bottom rather than moving
    // them mid-rise.
    property real carry: 0
    property bool arriving: false
    property bool seatWaitOver: false
    readonly property bool seated: root.seatWaitOver
        || !BottomSurfaceCoordinator.surfacePresent
        || !BottomSurfaceCoordinator.regionReserving

    // The keys go on at the speed they were sent with and slow to rest: an
    // ease-out curve starts at three times its average speed.
    function settleDuration(distance, speed) {
        if (speed <= 0) {
            return 240;
        }
        return Math.max(140, Math.min(320, 3000 * distance / speed));
    }

    function beginArrival() {
        carryMotion.stop();
        root.carry = root.panelHeight;
        root.arriving = true;
        // Keys waiting for the dock to leave are on their way up, not at
        // rest, so the window above is not made shorter for the moment they
        // stand at the edge.
        BottomSurfaceCoordinator.announceHeading(root.panelHeight, 700);
        root.seatWaitOver = false;
        seatWait.restart();
        root.advanceArrival();
    }

    function advanceArrival() {
        if (!root.arriving || !root.seated || seatSettle.running) {
            return;
        }
        // Keys the compositor has not shown are not on screen: an application
        // that focused its own field raised them, and Kadunce keeps those
        // down. They rise once the compositor shows them, so they are seen
        // rising rather than appearing where they rest.
        if (!root.compositorShown) {
            return;
        }
        root.travelTo(0, 240);
    }
    // The speed the keys were sent away at, which they carry on at as they go.
    property real pendingSpeed: 0

    function carryTo(target, duration, easing) {
        carryMotion.stop();
        carryMotion.to = target;
        carryMotion.duration = duration;
        carryMotion.easing.type = easing === undefined ? Easing.OutCubic : easing;
        carryMotion.start();
    }

    // A motion with a destination: whatever draws the window above the keys
    // is told where they will rest and when before they move, so it can
    // follow them without asking the window for a new size on every frame.
    function travelTo(target, duration, easing) {
        BottomSurfaceCoordinator.announceHeading(root.panelHeight - target, duration);
        root.carryTo(target, duration, easing);
    }

    // Putting the keys away, with Hide or the tray entry, ends the latch
    // first: a latched trackpad asks for the keys back the moment they go,
    // so they would come straight back up.
    function putAway() {
        root.precisionHeld = false;
        root.closing = true;
        root.travelTo(root.panelHeight,
                      root.settleDuration(root.panelHeight - root.carry, -root.pendingSpeed));
    }
    property bool closing: false

    // The Hide key. The window above is told now, so it has its height back
    // before the keys uncover it.
    function hideKeys() {
        BottomSurfaceCoordinator.announceHeading(0, 0);
        root.pendingSpeed = 0;
        root.putAway();
    }

    // Typing ended, so the keys go: down the way Hide sends them, and
    // the window once they have. They start gently, so the window above has
    // its height back before they uncover it. Keys held up for the precision
    // surface, or already down, go at once as before.
    property bool leaving: false
    function slideAway() {
        if (root.precisionActive || !root.visible || root.carry >= root.panelHeight) {
            handover.stop();
            root.finishLeaving();
            return;
        }
        if (!root.leaving) handover.start();
    }
    // A field letting go is often a field handing over: a browser moving
    // between two of its boxes lets go of one and asks for the keys again a
    // few milliseconds later. The keys wait this long before they go, so a
    // handover moves nothing and tells the window above nothing.
    Timer {
        id: handover
        interval: 150
        onTriggered: {
            root.leaving = true;
            root.closing = false;
            root.arriving = false;
            root.travelTo(root.panelHeight, 280, Easing.InOutCubic);
        }
    }
    // Out of sight: the window goes, and so does the input method's own
    // visibility, which is what brings the window back when the keys are
    // next asked for.
    function finishLeaving() {
        root.leaving = false;
        if (Qt.inputMethod.visible) Qt.inputMethod.hide();
        else root.visible = false;
    }
    // Asked for again on the way out: they come back up from where they are,
    // or, before they have set off, simply stay.
    function returnFromLeaving() {
        handover.stop();
        if (!root.leaving) return;
        root.leaving = false;
        root.travelTo(0, 240);
    }
    Connections {
        target: Qt.inputMethod
        function onVisibleChanged() {
            if (Qt.inputMethod.visible) root.returnFromLeaving();
        }
    }

    NumberAnimation {
        id: carryMotion
        target: root
        property: "carry"
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.leaving) {
                root.finishLeaving();
            } else if (root.closing) {
                root.closing = false;
                root.arriving = false;
                Qt.inputMethod.hide();
            } else if (root.carry === 0) {
                root.arriving = false;
            }
        }
    }

    // The compositor places the keys again a frame after the reservation
    // goes; this is that frame's grace, and a limit for a surface that never
    // says it has gone.
    Timer {
        id: seatSettle
        interval: 40
        onTriggered: root.advanceArrival()
    }
    Timer {
        id: seatWait
        interval: 450
        onTriggered: {
            root.seatWaitOver = true;
            root.advanceArrival();
        }
    }
    onSeatedChanged: {
        if (root.seated && root.arriving) {
            seatSettle.restart();
        }
    }

    // Whether the compositor has shown these keys since the window last came
    // up. Until it has, a report that they are hidden is about the keys
    // before, and keys it has not shown are not on screen to rise.
    property bool compositorShown: false
    // An application can ask the compositor to put the keys away without the
    // Keyboard being told. They go the same way, and come back if the
    // compositor shows them again before they are out.
    Connections {
        target: BottomSurfaceCoordinator
        function onCompositorVisibilityChecked(visible) {
            if (visible) {
                const first = !root.compositorShown;
                root.compositorShown = true;
                root.returnFromLeaving();
                // Shown at last after waiting out of sight: the dock may only
                // now be stepping aside, so the wait for it starts again.
                if (first && root.arriving) {
                    root.seatWaitOver = false;
                    seatWait.restart();
                    root.advanceArrival();
                }
            } else if (root.visible && root.compositorShown && !root.leaving && !root.precisionActive) {
                root.compositorShown = false;
                root.slideAway();
            }
        }
    }

    function keyCode(text) {
        if (text === " ") return Qt.Key_Space;
        return text.toUpperCase().charCodeAt(0);
    }

    function probeCharacter(text) {
        const modifiers = text !== text.toLowerCase() ? Qt.ShiftModifier : Qt.NoModifier;
        inputEngine.InputContext.inputEngine.virtualKeyClick(keyCode(text), text, modifiers);
    }

    // What a key means, handed to the input method. A chord, or a key with no
    // text under Shift (Shift and an arrow selects), goes as a shortcut so
    // the compositor sees its modifiers; anything else is a key click.
    function deliver(key, text, modifiers) {
        if (keyField.asShortcut(key, text, modifiers)) {
            thing.sendShortcut(key, modifiers);
        } else {
            inputEngine.InputContext.inputEngine.virtualKeyClick(key, text, modifiers);
        }
    }

    function beginPrecision() {
        precisionController.ensureSession();
        precisionController.keepKeyboardVisible();
    }

    function updateLocales() {
        let locale = Qt.locale().name;
        if (locale === "C") locale = "en_US";
        VirtualKeyboardSettings.activeLocales = PlasmaKeyboardSettings.enabledLocales.length > 0
                                              ? PlasmaKeyboardSettings.enabledLocales : [locale];
    }

    onVisibleChanged: {
        root.compositorShown = false;
        if (visible) {
            beginArrival();
            precisionController.warmIfGranted();
        } else {
            // The carry stays where the keys were. The panel is still mapped
            // while this runs, so returning it to zero would report the whole
            // Keyboard for a moment after the keys have gone, and the card
            // above would make room for keys that are not there. An arrival
            // sets the carry afresh.
            carryMotion.stop();
            handover.stop();
            arriving = false;
            closing = false;
            leaving = false;
        }
        if (!visible) {
            keyField.clearOneShots();
            keyField.releaseHolds();
            if (precisionActive) Qt.callLater(precisionController.keepKeyboardVisible);
        }
    }

    onPrecisionActiveChanged: {
        if (precisionActive) beginPrecision();
    }

    onPanelHeightChanged: Qt.callLater(refreshInteractiveRegion)

    Component.onCompleted: {
        if (shuffleProbePrecision > 0) precisionHeld = true;
        if (shuffleProbeLayer > 0) keyField.activeLayer = "symbols";
    }

    // One boundary for the whole process. The keys and the cold-start hold are
    // separate surfaces, and two clients each believing they hold the region
    // is the state the boundary exists to prevent.
    Binding {
        target: BottomSurfaceCoordinator
        property: "requestedVisible"
        // Keys on their way out still hold the room, so the dock returns once
        // they have gone rather than under them.
        value: Qt.inputMethod.visible || root.leaving || root.precisionActive
        restoreMode: Binding.RestoreNone
    }

    Connections {
        target: BottomSurfaceCoordinator
        function onReservationRefreshRequested() {
            Qt.callLater(root.refreshInteractiveRegion);
        }
        function onKeyboardFocusReclaimRequested() {
            root.reclaimFocus();
        }
        // The keys' tray entry tapped while they are up.
        function onPutAwayRequested() {
            root.putAway();
        }
    }

    PrecisionController { id: precisionController }

    Connections {
        target: precisionController
        function onStateChanged() {
            if (root.precisionActive && precisionController.ready) {
                precisionController.keepKeyboardVisible();
            }
        }
    }

    InputPanel {
        id: inputEngine
        x: -2
        y: -2
        width: 1
        height: 1
        opacity: 0
        focusPolicy: Qt.NoFocus

        Component.onCompleted: {
            root.updateLocales();
        }
    }

    Connections {
        target: PlasmaKeyboardSettings
        function onEnabledLocalesChanged() { root.updateLocales(); }
    }

    InputListenerItem {
        id: thing
        focus: true
        engine: inputEngine.InputContext.inputEngine
    }

    Timer {
        interval: shuffleProbeDelay > 0 ? shuffleProbeDelay : 1
        running: shuffleProbeText.length > 0 && Qt.inputMethod.visible && !root.probeArmed
        onTriggered: root.probeArmed = true
    }

    Timer {
        interval: shuffleProbeInterval > 0 ? shuffleProbeInterval : 2
        repeat: true
        running: shuffleProbeText.length > 0 && Qt.inputMethod.visible && root.probeArmed
        onTriggered: {
            if (root.probeIndex >= root.probeLength) {
                stop();
                root.probeTypingComplete = true;
                return;
            }
            root.probeCharacter(shuffleProbeText.charAt(root.probeIndex++ % shuffleProbeText.length));
        }
    }

    Timer {
        interval: 80
        repeat: true
        running: shuffleProbeShortcuts && root.probeTypingComplete
        onTriggered: {
            const shortcutKeys = [Qt.Key_A, Qt.Key_C, Qt.Key_X, Qt.Key_V, Qt.Key_Z, Qt.Key_Z];
            if (root.probeShortcutStep < shortcutKeys.length) {
                const modifiers = root.probeShortcutStep === shortcutKeys.length - 1
                                ? Qt.ControlModifier | Qt.ShiftModifier : Qt.ControlModifier;
                thing.sendShortcut(shortcutKeys[root.probeShortcutStep++], modifiers);
                return;
            }
            const suffix = "DONE";
            const suffixIndex = root.probeShortcutStep++ - shortcutKeys.length;
            if (suffixIndex < suffix.length) {
                root.probeCharacter(suffix.charAt(suffixIndex));
                return;
            }
            stop();
        }
    }

    Timer {
        interval: 2500
        running: shuffleProbeDismiss && Qt.inputMethod.visible
        onTriggered: Qt.inputMethod.hide()
    }

    Rectangle {
        id: panel
        x: root.sideGutter
        y: root.height - height + root.carry
        width: root.width - root.sideGutter * 2
        height: root.panelHeight
        color: "transparent"

        // Rounded at the top only: the lower corners run past the screen's
        // edge, where nothing is drawn.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height + root.cardRadius
            radius: root.cardRadius
            color: "#141414"
            border.width: 1
            border.color: "#333333"
        }

        Item {
            id: keyboardBody
            anchors.fill: parent
            anchors.topMargin: root.topStrip
            anchors.leftMargin: root.outerGap
            anchors.rightMargin: root.outerGap
            anchors.bottomMargin: root.outerGap
            opacity: root.precisionHeld ? 0.28 : 1

            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

            KeyField {
                id: keyField
                enabled: !root.precisionActive
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth
                unitWidth: root.keyUnitWidth
                keyGap: root.keyGap
                terminal: thing.contentPurpose === 12

                onKeyRequested: (key, text, modifiers) => root.deliver(key, text, modifiers)
                onMetaRequested: thing.triggerGlobalShortcut(Qt.Key_Meta)
                onHideRequested: root.hideKeys()
            }
        }

        // The latch's hit target sits over the trackpad mark and above the
        // trackpad it opens, so the same tap closes it again.
        MouseArea {
            z: 2
            x: keyboardBody.x + keyField.x + keyField.markRect.x
            y: keyboardBody.y + keyField.y + keyField.markRect.y
            width: keyField.markRect.width
            height: keyField.markRect.height
            onClicked: root.precisionHeld = !root.precisionHeld

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#F8F8FF"
                opacity: root.precisionHeld ? 0.22 : 0
            }
        }

        // Hide stays live over the trackpad, as the mark does, and is drawn
        // undimmed so it reads as live: it puts the keys away and ends the
        // latch.
        MouseArea {
            z: 2
            visible: root.precisionActive
            x: keyboardBody.x + keyField.x + keyField.hideRect.x
            y: keyboardBody.y + keyField.y + keyField.hideRect.y
            width: keyField.hideRect.width
            height: keyField.hideRect.height
            onClicked: root.hideKeys()

            Accessible.role: Accessible.Button
            Accessible.name: i18n("Put the keyboard away")
            Accessible.onPressAction: root.hideKeys()

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#141414"
            }
            KeyCap {
                anchors.fill: parent
                glyph: "hide"
                down: parent.pressed
            }
        }

        PrecisionSurface {
            z: 1
            anchors.fill: parent
            anchors.topMargin: root.topStrip
            anchors.leftMargin: root.outerGap
            anchors.rightMargin: root.outerGap
            anchors.bottomMargin: root.outerGap
            visible: root.precisionActive
            controller: precisionController
            keyboardUnderlayVisible: root.precisionHeld
        }

    }
}
