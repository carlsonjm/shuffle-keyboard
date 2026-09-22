pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

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
                    + " keyboard=" + BottomSurfaceCoordinator.keyboardVisible);
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

            onTapped: BottomSurfaceCoordinator.raiseKeyboard()
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
                    BottomSurfaceCoordinator.raiseKeyboard();
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
