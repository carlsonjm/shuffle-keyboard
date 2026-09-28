pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Window

import org.kde.layershell as LayerShell
import org.kde.plasma.keyboard

// Brings the keys up when Kadunce says a swipe up from the bottom bezel asked
// for them, including straight after signing in.
//
// Kadunce asks the compositor for the keys itself, which leaves the focus where
// it is: a text box that was ready is typed into, and the card that holds it
// pans it into view. Only a cold start needs more. Plasma shows a raised
// keyboard only once it has been allowed to, and straight after signing in a
// direct raise did nothing until some text field had been touched. When the
// keys have not come up shortly after Kadunce's request, this raises the way a
// text field does: a field nobody sees takes typing focus for as long as the
// keys are up, and gives the focus back when they go. Whatever is typed then
// goes nowhere until a text box is tapped, which is what a raise with nothing
// selected has always meant.
//
// The field is presented from this window: one transparent pixel that takes
// no touches, on the overlay layer, since KWin gives a layer surface the focus
// when it asks only on the top and overlay layers. The keys' own window is an
// input panel, which the compositor never gives the focus.
Window {
    id: root

    width: 1
    height: 1
    color: "transparent"
    // Asking Qt not to focus this window does not stop Qt following the
    // compositor's focus here, which is what reclaiming below is for, but it
    // narrows the moment: without it the raise failed one isolated run in
    // three, with it none in fifteen.
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    visible: false

    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.scope: "shuffle-keyboard-focus"

    // Qt moves this process's own focus here along with the compositor's, and
    // the in-process virtual keyboard types into whatever Qt has focused and
    // hides when that is nothing it can type into. So Qt's focus goes straight
    // back to the keyboard's window, while the compositor's stays here with the
    // field.
    onActiveChanged: {
        if (root.active) {
            BottomSurfaceCoordinator.reclaimKeyboardFocus();
        }
    }

    TextInputHold {
        id: field

        // The compositor moving the focus off the field --- a touch on an
        // application --- ends the hold.
        property bool wasHeld: false

        onHeldChanged: {
            if (field.held) {
                field.wasHeld = true;
                // The field asking is what raises the keyboard.
            } else if (field.wasHeld && root.holdingFocus) {
                root.releaseFocus();
            }
        }
    }

    property bool holdingFocus: false
    // Only a keyboard that has been up during this hold and then goes ends it;
    // the focus moving here can hide one that was up before it.
    property bool heldKeyboardShown: false

    // Answering the same request twice changes nothing: keys already up, a
    // wait already running, or a hold already in place is the answer.
    function raise() {
        if (BottomSurfaceCoordinator.keyboardVisible || coldStart.running || root.holdingFocus) {
            return;
        }
        coldStart.restart();
    }

    // How long Kadunce's own ask has to show the keys before this treats the
    // raise as a cold start.
    Timer {
        id: coldStart

        interval: 300
        onTriggered: if (!BottomSurfaceCoordinator.keyboardVisible) {
            root.hold();
        }
    }

    function hold() {
        root.holdingFocus = true;
        root.heldKeyboardShown = false;
        field.wasHeld = false;
        field.hold();
        root.visible = true;
        focusRelease.restart();
    }

    function releaseFocus() {
        focusRelease.stop();
        dismissal.stop();
        root.holdingFocus = false;
        field.release();
        // Unmapped, this window's focus goes back to whatever had it before.
        root.visible = false;
        BottomSurfaceCoordinator.reclaimKeyboardFocus();
    }

    // A raise that never brings the keyboard up must not keep the focus, or
    // what is typed on a real keyboard afterwards would vanish into the field.
    // Where the compositor offers no text input to ask with, a forced raise is
    // the only way in, and this is when it is tried.
    Timer {
        id: fallbackRaise

        interval: 300
        running: root.holdingFocus && !field.held
        onTriggered: BottomSurfaceCoordinator.raiseKeyboard()
    }

    // The focus arriving here can hide the keyboard for a moment and show it
    // again. Only a keyboard that stays down has been dismissed.
    Timer {
        id: dismissal

        interval: 200
        onTriggered: if (!BottomSurfaceCoordinator.keyboardVisible) {
            root.releaseFocus();
        }
    }

    Timer {
        id: focusRelease

        interval: 1500
        onTriggered: if (!root.heldKeyboardShown) {
            root.releaseFocus();
        }
    }

    Connections {
        target: BottomSurfaceCoordinator

        function onKeysRequested() {
            root.raise();
        }

        function onKeyboardVisibleChanged() {
            if (BottomSurfaceCoordinator.keyboardVisible) {
                coldStart.stop();
            }
            if (!root.holdingFocus) {
                return;
            }
            if (BottomSurfaceCoordinator.keyboardVisible) {
                root.heldKeyboardShown = true;
                focusRelease.stop();
                dismissal.stop();
            } else if (root.heldKeyboardShown) {
                dismissal.restart();
            }
        }
    }
}
