pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// A vertical scrub control in the width beside the keys: close to invisible
// until a finger arrives, then a column of notches with the current one lit.
// Each notch is one step. The device has no haptics, so a notch is felt two
// other ways: the finger passes a little beyond the halfway point before the
// value gives, the way a detent holds, and each step clicks.
Item {
    id: root

    // Finger travel per notch, in logical pixels.
    property real notchStep: 24
    // How far past halfway the finger goes before a notch gives, as a share
    // of a notch.
    property real notchHold: 0.2
    // Up is positive unless the control says otherwise.
    property bool downIsPositive: false
    // The notch in effect, and its bounds; unbounded where there are none.
    property int value: 0
    property int minimum: -1000000
    property int maximum: 1000000
    // A notch drawn bright whenever the column shows, such as a default.
    property bool marksHome: false
    property int home: 0

    readonly property bool active: touch.pressed

    // One notch was passed, in the direction given.
    signal stepped(int direction)
    signal released()

    // Where the finger went down and what was in effect then, in the
    // window's coordinates, since the column itself may move as it acts.
    property real startY: 0
    property int startValue: 0
    property real fingerY: 0

    function tryStep(windowY) {
        const along = (root.downIsPositive ? windowY - root.startY : root.startY - windowY) / root.notchStep;
        const offset = along - (root.value - root.startValue);
        const threshold = 0.5 + root.notchHold;
        if (offset > threshold && root.value < root.maximum) {
            root.value += 1;
            root.stepped(1);
            click.play();
            root.tryStep(windowY);
        } else if (offset < -threshold && root.value > root.minimum) {
            root.value -= 1;
            root.stepped(-1);
            click.play();
            root.tryStep(windowY);
        }
    }

    NotchClick {
        id: click
    }

    MouseArea {
        id: touch

        anchors.fill: parent
        preventStealing: true

        function windowY(mouse) {
            return touch.mapToItem(null, 0, mouse.y).y;
        }

        onPressed: mouse => {
            root.startY = windowY(mouse);
            root.startValue = root.value;
            root.fingerY = mouse.y;
        }
        onPositionChanged: mouse => {
            root.fingerY = mouse.y;
            root.tryStep(windowY(mouse));
        }
        onReleased: root.released()
        onCanceled: root.released()
    }

    // At rest: a faint line, so the column is findable but not furniture.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        width: 2
        height: parent.height * 0.76
        radius: 1
        color: "#F8F8FF"
        opacity: root.active ? 0.2 : 0.08

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    // Touched: the notches around the finger, the one in effect lit, and
    // the home notch bright wherever it falls.
    Item {
        id: notches

        anchors.fill: parent
        opacity: root.active ? 1 : 0
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        // The lit notch rests where the finger held it, then follows in
        // whole notches.
        readonly property real litY: root.fingerY

        Repeater {
            model: 11

            delegate: Rectangle {
                required property int index

                readonly property int offset: index - 5
                readonly property int notch: root.value + (root.downIsPositive ? offset : -offset)
                readonly property bool inRange: notch >= root.minimum && notch <= root.maximum
                readonly property bool isHome: root.marksHome && notch === root.home

                anchors.horizontalCenter: parent.horizontalCenter
                y: notches.litY + offset * root.notchStep - height / 2
                width: offset === 0 ? 28 : (isHome ? 22 : 12)
                height: offset === 0 ? 6 : 2
                radius: height / 2
                visible: inRange
                color: "#F8F8FF"
                opacity: offset === 0 ? 0.9 : (isHome ? 0.8 : Math.max(0.1, 0.4 - Math.abs(offset) * 0.06))
            }
        }
    }
}
