pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings

import org.kde.plasma.keyboard

InputPanelWindow {
    id: root

    width: Screen.width
    height: Screen.height
    color: "transparent"

    property bool symbolLayer: false
    property bool shiftActive: false
    property bool capsActive: false
    property bool controlActive: false
    property bool altActive: false
    property bool metaActive: false
    property bool precisionHeld: false
    property real dragStartY: 0
    property real dragStartHeight: 0
    property bool resizeMoved: false
    // The keyboard is a card: Kadunce's gutter at either side and nowhere
    // else, rounded where it stands free, flush with the screen's bottom edge
    // and lying over the window above it. Its top strip carries the handle
    // with clear room between the handle and the keys.
    readonly property real sideGutter: 10
    readonly property real cardRadius: 18
    readonly property real handleInset: 4
    readonly property real handleThickness: 6
    readonly property real handleClearance: 10
    readonly property real topStrip: handleInset + handleThickness + handleClearance

    // Key width is fixed and only key height moves, so the key columns and
    // the space bar never shift when the height changes. The key block is
    // about 80% of the width as first measured, sized up a tenth, and the
    // side columns take what is left. A key is square at the default.
    readonly property real keyBlockWidth: Math.round(root.width * 0.88)
    readonly property real keyGap: Math.max(5, Math.min(10, keyBlockWidth * 0.007))
    readonly property real outerGap: Math.max(6, Math.min(12, keyBlockWidth * 0.008))
    readonly property real keyUnitWidth: Math.max(1, (keyBlockWidth + keyGap) / 12.5 - keyGap)
    function heightForRows(row) {
        return Math.round(root.topStrip + row * 4 + root.keyGap * 3 + root.outerGap);
    }
    readonly property real squareDefaultHeight: heightForRows(keyUnitWidth)
    function persistKeyHeight() {
        const row = (root.panelHeight - root.topStrip - root.keyGap * 3 - root.outerGap) / 4;
        root.persistKeyRowHeight(Math.round(row));
    }
    // The saved height is a key height, since width no longer follows it; an
    // unset one is the square default.
    readonly property real savedHeight: PlasmaKeyboardSettings.keyRowHeight > 0
                                        ? heightForRows(PlasmaKeyboardSettings.keyRowHeight)
                                        : squareDefaultHeight
    property real requestedHeight: savedHeight
    property int probeIndex: 0
    property int probeShortcutStep: 0
    property bool probeArmed: shuffleProbeDelay <= 0
    property bool probeTypingComplete: false

    readonly property bool precisionActive: precisionHeld
    // A row never shorter than the common minimum touch target, 48 px; never
    // more than a quarter taller than a key is wide, and never over 55% of
    // the screen, so the keys stay keys and the card leaves the work above it.
    readonly property real minimumPanelHeight: heightForRows(48)
    readonly property real maximumPanelHeight: Math.max(minimumPanelHeight,
        Math.min(heightForRows(keyUnitWidth * 1.25), Math.round(root.height * 0.55)))
    readonly property real panelHeight: Math.round(Math.max(minimumPanelHeight, Math.min(maximumPanelHeight, requestedHeight)))
    readonly property int probeRepeat: shuffleProbeRepeat > 0 ? shuffleProbeRepeat : 1
    readonly property int probeLength: shuffleProbeText.length * probeRepeat
    readonly property var keyRows: {
        if (!symbolLayer) {
            return [["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]];
        }
        if (!shiftActive) {
            return [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                    ["@", "#", "$", "&", "*", "(", ")", "'", "\""],
                    ["%", "-", "+", "=", "/", ";", ":", "!", "?", ","]];
        }
        return [["[", "]", "{", "}", "<", ">", "~", "`", "^", "|"],
                ["Tab", "Esc", "Del", "Home", "End", "Pg↑", "Pg↓"],
                ["←", "↑", "↓", "→"]];
    }

    // Where the keys rest, not where they are drawn: a region that changes
    // makes the compositor place the panel again, which it must not do on
    // every frame of an arrival.
    interactiveRegion: Qt.rect(panel.x, root.height - panel.height, panel.width, panel.height)

    // The arrival. The keys start below the screen's edge and rise from it,
    // under the finger when a pull brought them and on their own otherwise.
    // They wait until the dock has left and given up its room, so they never
    // rise into the dock's room while it is there, and the compositor has
    // already placed them at the bottom rather than moving them mid-rise.
    property real carry: 0
    property bool arriving: false
    property bool pullActive: false
    // The finger's height above the screen's bottom edge.
    property real pullTravel: 0
    // Where the handle sits in the keys' top strip, which is where the finger
    // holds them.
    readonly property real grabCentre: root.handleInset + root.handleThickness / 2
    // A pull that ended before the keys could rise, which way it went, and
    // when: a decision older than a moment belongs to a pull whose keys never
    // came.
    property bool pendingSettle: false
    property bool pendingOpen: true
    property real pendingAt: 0
    property bool seatWaitOver: false
    readonly property bool seated: root.seatWaitOver
        || !BottomSurfaceCoordinator.surfacePresent
        || !BottomSurfaceCoordinator.regionReserving

    // Past a quarter of the way up, or a flick upward, a released pull opens.
    readonly property real openFraction: 0.25
    readonly property real flickSpeed: 400

    // How far the keys sit below their resting place with the handle under
    // the finger.
    function carryUnder(height) {
        return Math.max(0, Math.min(root.panelHeight, root.panelHeight - height - root.grabCentre));
    }

    // A released pull goes on at the finger's speed and slows to rest: an
    // ease-out curve starts at three times its average speed, so matching
    // that to the finger leaves no seam where the hand lets go.
    function settleDuration(distance, speed) {
        if (speed <= 0) {
            return 240;
        }
        return Math.max(140, Math.min(320, 3000 * distance / speed));
    }

    // Temporary: what the keys heard of a pull and what state they were in,
    // for the pass that finds why a pull from the dock is not followed.
    property real lastLoggedTravel: -1000
    function reportPull(what) {
        console.log("Shuffle keys: " + what + " height " + Math.round(root.pullTravel)
                    + " active " + root.pullActive + " arriving " + root.arriving
                    + " seated " + root.seated + " reserving "
                    + BottomSurfaceCoordinator.regionReserving + " visible " + root.visible
                    + " carry " + Math.round(root.carry) + " of " + Math.round(root.panelHeight));
    }

    function beginArrival() {
        root.reportPull("keys shown,");
        carryMotion.stop();
        root.carry = root.panelHeight;
        root.arriving = true;
        root.seatWaitOver = false;
        seatWait.restart();
        root.advanceArrival();
    }

    function advanceArrival() {
        if (!root.arriving || !root.seated || seatSettle.running) {
            return;
        }
        if (root.pullActive) {
            root.carryTo(root.carryUnder(root.pullTravel), 110);
        } else if (root.pendingSettle && !root.pendingOpen
                   && Date.now() - root.pendingAt < 1000) {
            root.pendingSettle = false;
            root.putAway();
        } else {
            const fromPull = root.pendingSettle;
            root.pendingSettle = false;
            root.carryTo(0, fromPull ? root.settleDuration(root.carry, root.pendingSpeed) : 240);
        }
    }
    property real pendingSpeed: 0

    function carryTo(target, duration) {
        carryMotion.stop();
        carryMotion.to = target;
        carryMotion.duration = duration;
        carryMotion.start();
    }

    function putAway() {
        root.closing = true;
        root.carryTo(root.panelHeight,
                     root.settleDuration(root.panelHeight - root.carry, -root.pendingSpeed));
    }
    property bool closing: false

    NumberAnimation {
        id: carryMotion
        target: root
        property: "carry"
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.closing) {
                root.closing = false;
                root.arriving = false;
                Qt.inputMethod.hide();
            } else if (root.carry === 0 && !root.pullActive) {
                root.arriving = false;
            }
        }
    }

    // The compositor places the keys again a frame after the reservation
    // goes; this is that frame's grace, and a limit for a surface that never
    // says it has gone.
    Timer {
        id: seatSettle
        interval: 60
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
        if (root.arriving) {
            root.reportPull("seated changed,");
        }
        if (root.seated && root.arriving) {
            seatSettle.restart();
        }
    }

    Connections {
        target: BottomSurfaceCoordinator
        function onKeyboardPulled(travel, active, velocity) {
            root.pullTravel = Math.max(0, travel);
            if (active) {
                const first = !root.pullActive;
                root.pullActive = true;
                if (first || Math.abs(root.pullTravel - root.lastLoggedTravel) >= 40) {
                    root.lastLoggedTravel = root.pullTravel;
                    root.reportPull(first ? "pull began" : "pull moved");
                }
                if (root.arriving && root.seated && !seatSettle.running && !carryMotion.running) {
                    root.carry = root.carryUnder(root.pullTravel);
                } else {
                    root.advanceArrival();
                }
                return;
            }
            root.reportPull("pull released at " + Math.round(velocity) + " px/s,");
            root.lastLoggedTravel = -1000;
            if (!root.pullActive) {
                return;
            }
            root.pullActive = false;
            root.pendingSettle = true;
            root.pendingSpeed = Math.min(velocity, 4000);
            root.pendingOpen = root.pullTravel >= root.panelHeight * root.openFraction
                || velocity >= root.flickSpeed;
            root.pendingAt = Date.now();
            root.advanceArrival();
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

    function clearOneShotModifiers() {
        shiftActive = false;
        controlActive = false;
        altActive = false;
        metaActive = false;
    }

    function sendCharacter(text) {
        const alphabetic = !symbolLayer && text.length === 1 && text >= "a" && text <= "z";
        const uppercase = alphabetic && (shiftActive !== capsActive);
        let output = uppercase ? text.toUpperCase() : text;
        if (!symbolLayer && shiftActive && !alphabetic) {
            if (text === ",") output = "<";
            else if (text === ".") output = ">";
            else if (text === "/") output = "?";
        }
        const textShift = alphabetic ? uppercase : (shiftActive && !symbolLayer);
        const modifiers = (textShift ? Qt.ShiftModifier : Qt.NoModifier)
                          | (controlActive ? Qt.ControlModifier : Qt.NoModifier)
                          | (altActive ? Qt.AltModifier : Qt.NoModifier)
                          | (metaActive ? Qt.MetaModifier : Qt.NoModifier);
        if (controlActive || altActive || metaActive) {
            thing.sendShortcut(keyCode(text), modifiers);
        } else {
            inputEngine.InputContext.inputEngine.virtualKeyClick(keyCode(text), output, modifiers);
        }
        clearOneShotModifiers();
    }

    function displayLabel(label) {
        if (!symbolLayer && label.length === 1 && label >= "a" && label <= "z"
                && (shiftActive !== capsActive)) return label.toUpperCase();
        return label;
    }

    function secondaryLabel(label) {
        if (symbolLayer) return "";
        if (label === ",") return "<";
        if (label === ".") return ">";
        if (label === "/") return "?";
        return "";
    }

    function sendSpecial(key, text) {
        const modifiers = (shiftActive && !symbolLayer ? Qt.ShiftModifier : Qt.NoModifier)
                          | (controlActive ? Qt.ControlModifier : Qt.NoModifier)
                          | (altActive ? Qt.AltModifier : Qt.NoModifier)
                          | (metaActive ? Qt.MetaModifier : Qt.NoModifier);
        if (controlActive || altActive || metaActive) thing.sendShortcut(key, modifiers);
        else inputEngine.InputContext.inputEngine.virtualKeyClick(key, text, modifiers);
        clearOneShotModifiers();
    }

    function dispatchLabel(label) {
        if (label === "Tab") sendSpecial(Qt.Key_Tab, "\t");
        else if (label === "Esc") sendSpecial(Qt.Key_Escape, "");
        else if (label === "Del") sendSpecial(Qt.Key_Delete, "");
        else if (label === "Home") sendSpecial(Qt.Key_Home, "");
        else if (label === "End") sendSpecial(Qt.Key_End, "");
        else if (label === "Pg↑") sendSpecial(Qt.Key_PageUp, "");
        else if (label === "Pg↓") sendSpecial(Qt.Key_PageDown, "");
        else if (label === "←") sendSpecial(Qt.Key_Left, "");
        else if (label === "↑") sendSpecial(Qt.Key_Up, "");
        else if (label === "↓") sendSpecial(Qt.Key_Down, "");
        else if (label === "→") sendSpecial(Qt.Key_Right, "");
        else sendCharacter(label);
    }

    function sendEditAction(action) {
        if (action === "Click") {
            precisionController.primaryClick();
            return;
        }
        // Terminal emulators conventionally reserve Ctrl+C for interrupt and
        // use Ctrl+Shift+C/V for clipboard actions.
        if (thing.contentPurpose === 12) {
            if (action === "Copy") thing.sendShortcut(Qt.Key_C, Qt.ControlModifier | Qt.ShiftModifier);
            else if (action === "Paste") thing.sendShortcut(Qt.Key_V, Qt.ControlModifier | Qt.ShiftModifier);
            return;
        }
        if (action === "Copy") thing.sendShortcut(Qt.Key_C, Qt.ControlModifier);
        else if (action === "Cut") thing.sendShortcut(Qt.Key_X, Qt.ControlModifier);
        else if (action === "Paste") thing.sendShortcut(Qt.Key_V, Qt.ControlModifier);
        else if (action === "Undo") thing.sendShortcut(Qt.Key_Z, Qt.ControlModifier);
        else if (action === "Redo") thing.sendShortcut(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
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
        if (visible) {
            beginArrival();
        } else {
            carryMotion.stop();
            arriving = false;
            closing = false;
            carry = 0;
        }
        if (!visible) {
            clearOneShotModifiers();
            if (precisionActive) Qt.callLater(precisionController.keepKeyboardVisible);
        }
    }

    onPrecisionActiveChanged: {
        if (precisionActive) beginPrecision();
    }

    onPanelHeightChanged: Qt.callLater(refreshInteractiveRegion)

    Component.onCompleted: {
        if (shuffleProbePrecision > 0) precisionHeld = true;
        if (shuffleProbeLayer > 0) symbolLayer = true;
        if (shuffleProbeLayer > 1) shiftActive = true;
    }

    // One boundary for the whole process. The keyboard and the handle are
    // separate surfaces and both speak to the same region, and two clients
    // each believing they hold it is the state the boundary exists to prevent.
    Binding {
        target: BottomSurfaceCoordinator
        property: "requestedVisible"
        value: Qt.inputMethod.visible || root.precisionActive
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
        interval: 1500
        running: shuffleProbeHeight > 0 && Qt.inputMethod.visible
        onTriggered: {
            root.requestedHeight = shuffleProbeHeight;
            root.persistKeyHeight();
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

        // The keys' top edge carries the dock's handle: the bar that was
        // pulled, at the dock row's place and width, so what the finger
        // brought up is what it holds. Without the surface there is no dock
        // row to match, and the bar keeps a width of its own.
        Rectangle {
            id: resizeHandle
            z: 20
            anchors.top: parent.top
            x: BottomSurfaceCoordinator.surfacePresent && BottomSurfaceCoordinator.dockWidth > 0
               ? BottomSurfaceCoordinator.dockLeft - panel.x : (parent.width - width) / 2
            width: BottomSurfaceCoordinator.surfacePresent && BottomSurfaceCoordinator.dockWidth > 0
                   ? BottomSurfaceCoordinator.dockWidth : 160
            height: root.topStrip
            color: "transparent"

            Rectangle {
                y: root.handleInset
                width: parent.width
                height: root.handleThickness
                radius: height / 2
                color: "#F8F8FF"
                opacity: root.pullActive || grabArea.pressed ? 0.9 : 0.35

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // The handle takes the keys away the way it brought them: a drag
            // down carries them under the finger and, past a quarter of the
            // way or on a flick, lets them go; otherwise they spring back. A
            // tap puts them away the same way. Up still makes them taller
            // until height has its own control. Positions are the window's,
            // because the handle moves with the keys it is dragging.
            MouseArea {
                id: grabArea
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor

                property real lastY: 0
                property real lastTime: 0
                property real downSpeed: 0

                function windowY(mouse) {
                    return mouse.y + resizeHandle.y + panel.y;
                }

                onPressed: mouse => {
                    root.dragStartY = windowY(mouse);
                    root.dragStartHeight = root.panelHeight;
                    root.resizeMoved = false;
                    carryMotion.stop();
                    lastY = root.dragStartY;
                    lastTime = Date.now();
                    downSpeed = 0;
                }
                onPositionChanged: mouse => {
                    if (!pressed) {
                        return;
                    }
                    const y = windowY(mouse);
                    const now = Date.now();
                    if (now > lastTime) {
                        downSpeed = (y - lastY) * 1000 / (now - lastTime);
                    }
                    lastY = y;
                    lastTime = now;
                    const rise = root.dragStartY - y;
                    if (Math.abs(rise) > 4) root.resizeMoved = true;
                    if (rise >= 0) {
                        root.carry = 0;
                        root.requestedHeight = root.dragStartHeight + rise;
                    } else {
                        root.requestedHeight = root.dragStartHeight;
                        root.carry = Math.min(root.panelHeight, -rise);
                    }
                }
                onReleased: {
                    if (root.carry > 0) {
                        root.pendingSpeed = -downSpeed;
                        if (root.carry >= root.panelHeight * root.openFraction
                                || downSpeed >= root.flickSpeed) {
                            root.putAway();
                        } else {
                            root.carryTo(0, root.settleDuration(root.carry, -downSpeed));
                        }
                    }
                    root.persistKeyHeight();
                }
                onCanceled: {
                    root.requestedHeight = root.savedHeight;
                    root.carryTo(0, 200);
                }
                onClicked: {
                    if (!root.resizeMoved) {
                        root.pendingSpeed = 0;
                        root.putAway();
                    }
                }
            }
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

            // Centering leaves a reachable Shuffle hold surface for either
            // pinky. Both surfaces hand off to the same full-footprint
            // precision overlay.
            EditGestureSurface {
                x: 0
                y: 0
                width: Math.max(0, keyField.x)
                height: keyboardBody.height
                onActionRequested: action => root.sendEditAction(action)
                onPrecisionHoldRequested: root.precisionHeld = true
                onPrecisionReleaseRequested: root.precisionHeld = false
            }

            EditGestureSurface {
                x: keyField.x + keyField.columnX(12.5)
                y: 0
                width: Math.max(0, keyboardBody.width - x)
                height: keyboardBody.height
                onActionRequested: action => root.sendEditAction(action)
                onPrecisionHoldRequested: root.precisionHeld = true
                onPrecisionReleaseRequested: root.precisionHeld = false
            }

            Item {
                id: keyField
                enabled: !root.precisionActive
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, root.keyBlockWidth)

                readonly property real rowHeight: (height - root.keyGap * 3) / 4
                readonly property real totalUnits: 12.5
                readonly property real unitPitch: (width + root.keyGap) / totalUnits
                readonly property real unitWidth: Math.max(1, unitPitch - root.keyGap)
                readonly property real qOffset: 1
                readonly property real homeOffset: 1.25
                readonly property real shiftSpan: 1.75

                function columnX(column) {
                    return column * unitPitch;
                }

                function spanWidth(span) {
                    return span * unitPitch - root.keyGap;
                }

                Repeater {
                    model: root.keyRows[0]

                    ShuffleButton {
                        required property int index
                        required property string modelData
                        x: keyField.columnX(index + keyField.qOffset)
                        y: 0
                        width: keyField.spanWidth(1)
                        height: keyField.rowHeight
                        label: root.displayLabel(modelData)
                        onTriggered: root.dispatchLabel(modelData)
                    }
                }

                Repeater {
                    model: root.keyRows[1]

                    ShuffleButton {
                        required property int index
                        required property string modelData
                        readonly property real cellSpan: root.symbolLayer && root.shiftActive
                                                                ? 9 / root.keyRows[1].length : 1
                        x: keyField.columnX(keyField.homeOffset + index * cellSpan)
                        y: keyField.rowHeight + root.keyGap
                        width: keyField.spanWidth(cellSpan)
                        height: keyField.rowHeight
                        label: root.displayLabel(modelData)
                        onTriggered: root.dispatchLabel(modelData)
                    }
                }

                Repeater {
                    model: root.keyRows[2]

                    ShuffleButton {
                        required property int index
                        required property string modelData
                        readonly property real cellSpan: root.symbolLayer && root.shiftActive
                                                                ? 10 / root.keyRows[2].length : 1
                        x: keyField.columnX(keyField.shiftSpan + index * cellSpan)
                        y: (keyField.rowHeight + root.keyGap) * 2
                        width: keyField.spanWidth(cellSpan + (index === root.keyRows[2].length - 1 ? 0.75 : 0))
                        height: keyField.rowHeight
                        label: root.displayLabel(modelData)
                        secondaryLabel: root.secondaryLabel(modelData)
                        onTriggered: root.dispatchLabel(modelData)
                    }
                }

                ShuffleButton {
                    x: 0
                    y: 0
                    width: keyField.spanWidth(keyField.qOffset)
                    height: keyField.rowHeight
                    label: root.symbolLayer ? "ABC" : "123"
                    labelScale: 0.76
                    active: root.symbolLayer
                    onTriggered: {
                        root.symbolLayer = !root.symbolLayer;
                        root.clearOneShotModifiers();
                    }
                }

                ShuffleButton {
                    x: keyField.columnX(11)
                    y: 0
                    width: keyField.spanWidth(1.5)
                    height: keyField.rowHeight
                    label: "⌫"
                    repeat: true
                    onTriggered: root.sendSpecial(Qt.Key_Backspace, "")
                }

                ShuffleButton {
                    x: 0
                    y: keyField.rowHeight + root.keyGap
                    width: keyField.spanWidth(keyField.homeOffset)
                    height: keyField.rowHeight
                    label: "Tab"
                    labelScale: 0.72
                    onTriggered: root.sendSpecial(Qt.Key_Tab, "\t")
                }

                ShuffleButton {
                    x: keyField.columnX(10.25)
                    y: keyField.rowHeight + root.keyGap
                    width: keyField.spanWidth(2.25)
                    height: keyField.rowHeight
                    label: "Enter"
                    labelScale: 0.8
                    restingColor: "#B3F8F8FF"
                    pressedColor: "#D9F8F8FF"
                    labelColor: "#141414"
                    outlineColor: "#B3F8F8FF"
                    onTriggered: root.sendSpecial(Qt.Key_Return, "\n")
                }

                ShuffleButton {
                    x: 0
                    y: (keyField.rowHeight + root.keyGap) * 2
                    width: keyField.spanWidth(keyField.shiftSpan)
                    height: keyField.rowHeight
                    label: "Shift"
                    labelScale: 0.74
                    doubleTriggerEnabled: true
                    active: root.shiftActive || root.capsActive
                    onTriggered: {
                        if (root.symbolLayer) {
                            root.shiftActive = !root.shiftActive;
                        } else if (root.capsActive) {
                            root.capsActive = false;
                            root.shiftActive = false;
                        } else {
                            root.shiftActive = !root.shiftActive;
                        }
                    }
                    onDoubleTriggered: {
                        if (!root.symbolLayer) {
                            root.shiftActive = false;
                            root.capsActive = true;
                        }
                    }
                }

                ShuffleButton {
                    x: keyField.columnX(0)
                    y: (keyField.rowHeight + root.keyGap) * 3
                    width: keyField.spanWidth(1.5)
                    height: keyField.rowHeight
                    label: "Ctrl"
                    labelScale: 0.76
                    active: root.controlActive
                    onTriggered: root.controlActive = !root.controlActive
                }

                ShuffleButton {
                    x: keyField.columnX(1.5)
                    y: (keyField.rowHeight + root.keyGap) * 3
                    width: keyField.spanWidth(1.5)
                    height: keyField.rowHeight
                    label: "Alt"
                    labelScale: 0.76
                    active: root.altActive
                    onTriggered: root.altActive = !root.altActive
                }

                ShuffleButton {
                    x: keyField.columnX(3)
                    y: (keyField.rowHeight + root.keyGap) * 3
                    width: keyField.spanWidth(8)
                    height: keyField.rowHeight
                    label: "Space"
                    labelScale: 0.74
                    onTriggered: root.sendCharacter(" ")
                }

                ShuffleButton {
                    x: keyField.columnX(11)
                    y: (keyField.rowHeight + root.keyGap) * 3
                    width: keyField.spanWidth(1.5)
                    height: keyField.rowHeight
                    label: ""
                    dotGlyph: true
                    onTriggered: thing.triggerGlobalShortcut(Qt.Key_Meta)
                }
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
