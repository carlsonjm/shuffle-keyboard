/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: root

    required property var controller
    property bool keyboardUnderlayVisible: false
    required property KeysPalette colours

    color: keyboardUnderlayVisible ? "transparent" : colours.recessed
    radius: keyboardUnderlayVisible ? 0 : 8
    border.width: keyboardUnderlayVisible ? 0 : 1
    border.color: colours.recessedEdge

    property int maximumTouches: 0
    property point previous: Qt.point(0, 0)
    property point origin: Qt.point(0, 0)
    property real travel: 0
    property bool dragging: false
    readonly property real tapSlop: 30
    readonly property real holdSlop: 24

    function pressedCount() {
        return (p1.pressed ? 1 : 0) + (p2.pressed ? 1 : 0);
    }

    function center() {
        if (p1.pressed && p2.pressed) return Qt.point((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
        if (p1.pressed) return Qt.point(p1.x, p1.y);
        if (p2.pressed) return Qt.point(p2.x, p2.y);
        return previous;
    }

    function finishGesture() {
        if (pressedCount() !== 0) return;
        holdTimer.stop();
        if (dragging) {
            controller.primaryUp();
            dragging = false;
        } else if (travel < tapSlop) {
            if (maximumTouches === 1) controller.primaryClick();
            else if (maximumTouches === 2) controller.secondaryClick();
        } else if (maximumTouches === 2) {
            controller.scroll(0, 0, true);
        }
        maximumTouches = 0;
    }

    MultiPointTouchArea {
        anchors.fill: parent
        minimumTouchPoints: 1
        maximumTouchPoints: 2
        touchPoints: [TouchPoint { id: p1 }, TouchPoint { id: p2 }]

        onPressed: {
            const count = root.pressedCount();
            if (root.maximumTouches === 0) {
                root.maximumTouches = count;
                root.previous = root.center();
                root.origin = root.previous;
                root.travel = 0;
                holdTimer.restart();
            } else {
                root.maximumTouches = Math.max(root.maximumTouches, count);
                holdTimer.stop();
            }
        }

        onUpdated: {
            const count = root.pressedCount();
            root.maximumTouches = Math.max(root.maximumTouches, count);
            const now = root.center();
            const dx = now.x - root.previous.x;
            const dy = now.y - root.previous.y;
            root.previous = now;
            root.travel = Math.max(root.travel, Math.hypot(now.x - root.origin.x, now.y - root.origin.y));
            if (root.travel > root.holdSlop) holdTimer.stop();
            if (count === 1) root.controller.move(dx * 1.18, dy * 1.18);
            else if (count === 2) root.controller.scroll(dx, dy, false);
        }

        onReleased: Qt.callLater(root.finishGesture)
        onCanceled: {
            holdTimer.stop();
            if (root.dragging) root.controller.primaryUp();
            root.dragging = false;
            root.maximumTouches = 0;
        }
    }

    Timer {
        id: holdTimer
        interval: 460
        onTriggered: {
            if (root.pressedCount() === 1 && root.travel < root.holdSlop) {
                root.dragging = true;
                root.controller.primaryDown();
            }
        }
    }

    Controls.Label {
        anchors.centerIn: parent
        text: root.controller.ready ? "" : root.controller.message
        color: root.colours.recessedInk
        opacity: 0.62
        font.pixelSize: 14
    }

}
