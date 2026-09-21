pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

Rectangle {
    id: root

    signal actionRequested(string action)
    signal precisionHoldRequested()
    signal precisionReleaseRequested()

    color: "transparent"
    border.width: 0

    property int maximumTouches: 0
    property point origin: Qt.point(0, 0)
    property point latest: Qt.point(0, 0)
    property real travel: 0
    property bool consumed: false
    property bool precisionHolding: false
    property string feedback: ""

    function pressedCount() {
        return (p1.pressed ? 1 : 0) + (p2.pressed ? 1 : 0) + (p3.pressed ? 1 : 0);
    }

    function center() {
        let count = 0;
        let x = 0;
        let y = 0;
        for (const point of [p1, p2, p3]) {
            if (point.pressed) {
                x += point.x;
                y += point.y;
                count++;
            }
        }
        return count > 0 ? Qt.point(x / count, y / count) : latest;
    }

    function perform(action) {
        consumed = true;
        feedback = action;
        feedbackTimer.restart();
        actionRequested(action);
    }

    function finishGesture() {
        if (pressedCount() !== 0) {
            return;
        }
        holdTimer.stop();
        if (precisionHolding) {
            precisionHolding = false;
            precisionReleaseRequested();
        } else if (!consumed && travel > 42 && maximumTouches === 1) {
            const dx = latest.x - origin.x;
            if (dx < -48) perform("Undo");
            else if (dx > 48) perform("Redo");
        } else if (!consumed && travel <= 42) {
            if (maximumTouches === 1) {
                perform("Click");
            } else if (maximumTouches === 2) perform("Copy");
            else if (maximumTouches === 3) perform("Cut");
        }
        maximumTouches = 0;
        consumed = false;
        travel = 0;
    }

    MultiPointTouchArea {
        anchors.fill: parent
        minimumTouchPoints: 1
        maximumTouchPoints: 3
        touchPoints: [
            TouchPoint { id: p1 },
            TouchPoint { id: p2 },
            TouchPoint { id: p3 }
        ]

        onPressed: {
            const count = root.pressedCount();
            if (root.maximumTouches === 0) {
                root.maximumTouches = count;
                root.origin = root.center();
                root.latest = root.origin;
                root.travel = 0;
                root.consumed = false;
                holdTimer.restart();
            } else {
                root.maximumTouches = Math.max(root.maximumTouches, count);
                holdTimer.stop();
            }
        }

        onUpdated: {
            root.maximumTouches = Math.max(root.maximumTouches, root.pressedCount());
            root.latest = root.center();
            root.travel = Math.max(root.travel, Math.hypot(root.latest.x - root.origin.x, root.latest.y - root.origin.y));
            if (root.travel > 14) holdTimer.stop();
        }

        onReleased: Qt.callLater(root.finishGesture)
        onCanceled: {
            holdTimer.stop();
            if (root.precisionHolding) root.precisionReleaseRequested();
            root.precisionHolding = false;
            root.maximumTouches = 0;
            root.consumed = true;
        }
    }

    Timer {
        id: holdTimer
        interval: 560
        onTriggered: {
            if (root.pressedCount() === 1 && root.travel < 14) {
                root.consumed = true;
                root.precisionHolding = true;
                root.precisionHoldRequested();
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: 520
        onTriggered: root.feedback = ""
    }

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 10
        height: 10
        radius: 5
        color: "#F8F8FF"
        opacity: 0.48
        visible: root.feedback.length > 0
    }
}
