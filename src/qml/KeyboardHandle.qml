pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

import org.kde.plasma.keyboard

HandleWindow {
    id: root

    // Kadunce keeps this much clear above anything reserving a strut at the
    // bottom edge, around every card and pane. The handle takes that room
    // rather than asking for room of its own, which is why the bar inside is
    // an even number of pixels: two clear, a hairline, four of handle, a
    // hairline, two clear.
    readonly property int gutter: 10
    readonly property int thickness: 4
    readonly property int hairline: 1

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
    // extent rather than floating over it at some width of its own.
    //
    // The light fill alone disappears over a light window running under the
    // gutter, and this surface cannot see what is beneath it to adapt. A dark
    // hairline edge carries it there, and all but vanishes over dark content,
    // where the fill already reads. The edge stays at the same strength while
    // the fill brightens, so pressing reads as the bar lighting up.
    Rectangle {
        id: bar

        x: BottomSurfaceCoordinator.dockLeft
        y: (root.gutter - root.thickness) / 2 - root.hairline
        width: Math.max(0, BottomSurfaceCoordinator.dockWidth)
        height: root.thickness + 2 * root.hairline
        radius: height / 2

        color: "transparent"
        border.width: root.hairline
        border.color: Qt.rgba(0, 0, 0, 0.28)
        opacity: root.wanted ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.hairline
            radius: height / 2

            color: "#F8F8FF"
            opacity: press.pressed || lift.active ? 0.9 : 0.35

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
