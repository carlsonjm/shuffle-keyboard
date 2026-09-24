pragma ComponentBehavior: Bound

/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

import org.kde.kirigami as Kirigami

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
    // of a notch. Small, so it reads at the speed a hand actually moves.
    property real notchHold: 0.1
    // Up is positive unless the control says otherwise.
    property bool downIsPositive: false
    // The notch in effect, and its bounds; unbounded where there are none.
    property int value: 0
    property int minimum: -1000000
    property int maximum: 1000000
    // A notch drawn bright whenever the column shows, such as a default.
    property bool marksHome: false
    property int home: 0
    // While held: what the column is, in small capitals under the line, and
    // what it reads, at the top of the line, as text or as a pair of icons.
    property string name: ""
    property string reading: ""
    property var readingIcons: []
    // The way the last notch went during this hold, or zero before the first.
    property int lastDirection: 0

    // The line the notches sit on; nothing is drawn beyond it.
    readonly property real trackTop: height * 0.12
    readonly property real trackBottom: height * 0.88

    readonly property bool active: touch.pressed

    // One notch was passed, in the direction given.
    signal stepped(int direction)
    signal released()

    // Where the finger went down and what was in effect then, in the
    // window's coordinates, since the column itself may move as it acts.
    property real startY: 0
    property int startValue: 0
    // Where the press landed, in this column's coordinates as it is now. The
    // notches stay put there while the lit one moves over them; the column
    // may itself move, as the height column does, so this is kept current.
    property real anchorY: 0
    function refreshAnchor() {
        root.anchorY = root.startY - touch.mapToItem(null, 0, 0).y;
    }
    // Where notch n sits on the line.
    function notchY(n) {
        const k = n - root.startValue;
        return root.anchorY + (root.downIsPositive ? k : -k) * root.notchStep;
    }

    function tryStep(windowY) {
        const along = (root.downIsPositive ? windowY - root.startY : root.startY - windowY) / root.notchStep;
        const offset = along - (root.value - root.startValue);
        const threshold = 0.5 + root.notchHold;
        if (offset > threshold && root.value < root.maximum) {
            root.value += 1;
            root.lastDirection = 1;
            root.stepped(1);
            click.play();
            root.tryStep(windowY);
        } else if (offset < -threshold && root.value > root.minimum) {
            root.value -= 1;
            root.lastDirection = -1;
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
            root.lastDirection = 0;
            root.refreshAnchor();
        }
        onPositionChanged: mouse => {
            root.tryStep(windowY(mouse));
            root.refreshAnchor();
        }
        onReleased: root.released()
        onCanceled: root.released()
    }

    // At rest: a faint line, so the column is findable but not furniture.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.trackTop
        width: 2
        height: root.trackBottom - root.trackTop
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

    // Touched: the notches stay where they are and the lit one moves over
    // them, a notch at a time; the home notch is bright wherever it falls.
    Item {
        id: notches

        anchors.fill: parent
        opacity: root.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: 15

            delegate: Rectangle {
                required property int index

                readonly property int notch: root.value + index - 7
                readonly property bool lit: notch === root.value
                readonly property bool isHome: root.marksHome && notch === root.home
                readonly property real centre: root.notchY(notch)
                // Notches thin out toward the line's ends and are never
                // drawn beyond them.
                readonly property real edgeFade: Math.max(0, Math.min(1,
                    Math.min(centre - root.trackTop, root.trackBottom - centre) / root.notchStep))

                anchors.horizontalCenter: parent.horizontalCenter
                y: centre - height / 2
                width: lit ? 36 : (isHome ? 22 : 12)
                height: lit ? 6 : 2
                radius: height / 2
                visible: notch >= root.minimum && notch <= root.maximum
                    && centre >= root.trackTop && centre <= root.trackBottom
                color: "#F8F8FF"
                opacity: lit ? 1 : (isHome ? 0.8 : 0.3) * edgeFade

                Behavior on width {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // What it reads, at the top of the line.
        Text {
            visible: root.reading !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, root.trackTop - height - 6)
            text: root.reading
            color: "#F8F8FF"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Row {
            visible: root.readingIcons.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, root.trackTop - height - 6)
            spacing: 10

            Repeater {
                model: root.readingIcons

                delegate: Kirigami.Icon {
                    required property string modelData
                    width: 16
                    height: 16
                    source: modelData
                    isMask: true
                    color: "#F8F8FF"
                    opacity: 0.8
                }
            }
        }

        // What the column is, under the line.
        Text {
            visible: root.name !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.min(parent.height - height, root.trackBottom + 6)
            text: root.name
            color: "#F8F8FF"
            opacity: 0.6
            font.pixelSize: 10
            font.letterSpacing: 1
            font.capitalization: Font.AllUppercase
        }
    }
}
