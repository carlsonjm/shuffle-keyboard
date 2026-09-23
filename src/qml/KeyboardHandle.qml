pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Window

import org.kde.layershell as LayerShell
import org.kde.plasma.keyboard

HandleWindow {
    id: root

    // The bar sits directly on the dock's band and reserves its own height,
    // so the work area stops at its top edge. Whatever keeps a gutter above
    // the work area --- Kadunce keeps ten around every card and pane --- keeps
    // it above the bar, and the dock keeps its own ten between the band's top
    // and the icons: the bar reads as one more step of the same spacing. The
    // surface is the gutter's height so a reach that lands just above the bar
    // still takes it, over room that is empty by design.
    readonly property int gutter: 10
    readonly property int thickness: 6

    // Reaching for it is a distance, not a wait --- the rule the space bar's
    // pointer already uses.
    readonly property int armDistance: 8

    readonly property bool wanted: root.placed
        && BottomSurfaceCoordinator.surfacePresent
        && BottomSurfaceCoordinator.dockWidth > 0
        // It goes before the region darkens, so a blackout is announced by
        // something leaving rather than by a surface changing colour
        // unprompted. Which is why the surface publishes that state instead of
        // each process working it out: two answers would disagree and leave a
        // handle floating over a black strip.
        && !BottomSurfaceCoordinator.regionObscured
        // With the keyboard up, the keyboard is the surface being used and the
        // dock this reports the width of has stepped aside.
        && !BottomSurfaceCoordinator.keyboardVisible

    // Held through a blackout rather than following the bar out, because
    // letting it go would resize every window each time the region darkens and
    // clears. It goes with the dock and while the keyboard is up.
    reservation: root.placed
        && BottomSurfaceCoordinator.surfacePresent
        && BottomSurfaceCoordinator.dockWidth > 0
        && !BottomSurfaceCoordinator.keyboardVisible
        ? root.thickness : 0

    // The only dimension this window chooses. Its width is the output's,
    // because it is anchored to both side edges.
    height: root.gutter

    // Stays mapped while it fades, and only then goes.
    visible: root.wanted || bar.opacity > 0

    color: "transparent"

    // Over the application row and nowhere else. Everything outside this is
    // the rest of the bottom gutter, and belongs to whatever is beneath.
    interactiveRegion: Qt.rect(bar.x, 0, bar.width, root.gutter)

    // What an isolated session can see of a surface it cannot photograph.
    // Inert unless a probe asks for it.
    function reportPlacement() {
        if (!shuffleProbeHandle) {
            return;
        }
        console.warn("handle placed=" + root.placed
                    + " visible=" + root.visible
                    + " left=" + bar.x
                    + " width=" + bar.width
                    + " height=" + root.height
                    + " present=" + BottomSurfaceCoordinator.surfacePresent
                    + " obscured=" + BottomSurfaceCoordinator.regionObscured
                    + " keyboard=" + BottomSurfaceCoordinator.keyboardVisible
                    + " holding=" + root.holdingFocus
                    + " holderActive=" + holder.active
                    + " fieldHeld=" + field.held);
    }

    onWantedChanged: root.reportPlacement()
    onInteractiveRegionChanged: root.reportPlacement()

    onVisibleChanged: {
        // A surface that was hidden was destroyed, and a region set against
        // the old one went with it.
        if (root.visible) {
            Qt.callLater(root.refreshInteractiveRegion);
        }
        root.reportPlacement();
    }
    Component.onCompleted: root.reportPlacement()

    // Plasma shows a raised keyboard only once it has been allowed to, and it
    // allows that only when a text field asks while touch was the last input.
    // A raise on its own never counts, so after signing in the handle did
    // nothing until some text field had been touched. So the handle raises the
    // way a text field does: a field nobody sees takes typing focus for as
    // long as the keyboard is up, and gives the focus back when it goes.
    // Whatever is typed from the handle goes nowhere, which is what a raise
    // with nothing selected has always meant.
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
            root.reportPlacement();
        }
    }
    property bool holdingFocus: false
    // Only a keyboard that has been up during this hold and then goes ends it;
    // the focus moving to the holder can hide one that was up before it.
    property bool heldKeyboardShown: false

    function raise() {
        root.holdingFocus = true;
        root.heldKeyboardShown = false;
        field.wasHeld = false;
        field.hold();
        holder.visible = true;
        focusRelease.restart();
        root.reportPlacement();
    }

    function releaseFocus() {
        focusRelease.stop();
        dismissal.stop();
        root.holdingFocus = false;
        field.release();
        // Unmapped, the holder's focus goes back to whatever had it before.
        holder.visible = false;
        BottomSurfaceCoordinator.reclaimKeyboardFocus();
        root.reportPlacement();
    }

    // The field is presented from a surface of its own rather than the handle's. KWin
    // gives a layer surface the focus when it asks only on the top and overlay
    // layers, and the handle is on the bottom one so that it sits on the dock;
    // the handle also leaves while the keyboard is up, which is exactly when
    // the focus has to be held. One transparent pixel that takes no touches.
    Window {
        id: holder

        width: 1
        height: 1
        color: "transparent"
        // The compositor gives it the focus; Qt must not treat it as this
        // process's focus window, or the in-process virtual keyboard sees a
        // window with nothing to type into and hides the keyboard again.
        flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
        visible: false

        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.scope: "shuffle-keyboard-focus"

        // Qt moves this process's own focus here along with the compositor's,
        // and the in-process virtual keyboard types into whatever Qt has
        // focused and hides when that is nothing it can type into. So Qt's
        // focus goes straight back to the keyboard's window, while the
        // compositor's stays here with the field.
        onActiveChanged: {
            if (holder.active) {
                BottomSurfaceCoordinator.reclaimKeyboardFocus();
            }
            root.reportPlacement();
        }

        onVisibleChanged: root.reportPlacement()
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

    // The focus arriving at the holder can hide the keyboard for a moment
    // and show it again. Only a keyboard that stays down has been dismissed.
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

        function onKeyboardVisibleChanged() {
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

    // What an isolated session uses in place of a finger, once.
    Timer {
        property bool fired: false

        interval: Math.max(1, shuffleProbeRaise)
        running: shuffleProbeRaise > 0 && root.wanted && !fired
        onTriggered: {
            fired = true;
            root.raise();
        }
    }

    Item {
        id: reach

        x: bar.x
        y: 0
        width: bar.width
        height: root.gutter

        // One raise per gesture. The threshold is crossed once on the way up
        // and the finger is still down afterwards.
        property bool lifted: false

        TapHandler {
            id: press

            onTapped: root.raise()
        }

        DragHandler {
            id: lift

            target: null
            xAxis.enabled: false

            onActiveChanged: if (!active) {
                reach.lifted = false;
            }

            onActiveTranslationChanged: {
                if (!reach.lifted && lift.activeTranslation.y <= -root.armDistance) {
                    reach.lifted = true;
                    root.raise();
                }
            }
        }
    }

    // Exactly over the application row, so the handle reports the dock's
    // extent rather than floating over it at some width of its own. It is
    // light and translucent, so the wallpaper reads through it, and it
    // brightens under the finger.
    Rectangle {
        id: bar

        x: BottomSurfaceCoordinator.dockLeft
        y: root.gutter - root.thickness
        width: Math.max(0, BottomSurfaceCoordinator.dockWidth)
        height: root.thickness
        radius: height / 2

        color: "#F8F8FF"
        opacity: root.wanted ? (press.pressed || lift.active ? 0.9 : 0.35) : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }
}
