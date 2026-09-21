/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: root

    required property string primaryLabel
    property string secondaryLabel: ""
    property bool special: false
    property bool accent: false
    property bool active: false
    property bool repeat: false
    signal triggered()

    radius: Math.max(5, Math.min(9, height * 0.12))
    color: accent ? "#0A84FF"
                  : (active ? "#99A1AC"
                            : (pointer.pressed ? "#D8DADE"
                                               : (special ? "#B8BEC7" : "#F7F7F8")))

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius
        anchors.rightMargin: root.radius
        height: 2
        radius: 1
        color: root.accent ? "#0870D7" : "#8E949D"
        opacity: 0.5
    }

    Column {
        anchors.centerIn: parent
        spacing: -2

        Controls.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.secondaryLabel.length > 0
            text: root.secondaryLabel
            color: root.accent ? "#FFFFFF" : "#17191C"
            font.pixelSize: Math.max(10, Math.min(root.height * 0.24, 16))
            font.weight: Font.Normal
        }

        Controls.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.primaryLabel
            color: root.accent ? "#FFFFFF" : "#17191C"
            font.pixelSize: root.secondaryLabel.length > 0
                            ? Math.max(11, Math.min(root.height * 0.27, 17))
                            : Math.max(13, Math.min(root.height * 0.38, 24))
            font.weight: Font.Normal
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        preventStealing: true
        onClicked: root.triggered()
        onPressed: {
            if (root.repeat) repeatDelay.restart();
        }
        onReleased: {
            repeatDelay.stop();
            repeatTimer.stop();
        }
        onCanceled: {
            repeatDelay.stop();
            repeatTimer.stop();
        }
    }

    Timer {
        id: repeatDelay
        interval: 430
        onTriggered: repeatTimer.start()
    }

    Timer {
        id: repeatTimer
        interval: 52
        repeat: true
        onTriggered: root.triggered()
    }
}
