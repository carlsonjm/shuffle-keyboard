/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: root

    required property string label
    property string secondaryLabel: ""
    property bool active: false
    property bool repeat: false
    property bool quiet: false
    property bool showOutline: true
    property bool dotGlyph: false
    property bool doubleTriggerEnabled: false
    property real labelScale: 1
    property color restingColor: "transparent"
    property color pressedColor: outlineColor
    property color activeColor: outlineColor
    property color labelColor: "#F8F8FF"
    property color activeLabelColor: labelColor
    property color outlineColor: "#383838"
    signal triggered()
    signal doubleTriggered()
    signal pressed()
    signal released()
    signal canceled()
    signal held()

    // Keys are paper: round keys would read as dots.
    radius: 8
    scale: pointer.pressed ? 0.99 : 1
    color: active ? activeColor : (pointer.pressed ? pressedColor : restingColor)
    border.width: showOutline ? 1 : 0
    border.color: outlineColor

    Behavior on color { ColorAnimation { duration: 70 } }
    Behavior on scale { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } }

    Controls.Label {
        anchors.centerIn: parent
        visible: !root.dotGlyph && root.secondaryLabel.length === 0
        text: root.label
        color: root.active ? root.activeLabelColor : root.labelColor
        opacity: root.active ? 1 : 0.84
        font.pixelSize: Math.max(14, Math.min(root.height * 0.34, 27) * root.labelScale)
        font.weight: Font.Normal
    }

    Column {
        anchors.centerIn: parent
        visible: !root.dotGlyph && root.secondaryLabel.length > 0
        spacing: -2

        Controls.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.secondaryLabel
            color: root.active ? root.activeLabelColor : root.labelColor
            opacity: root.active ? 1 : 0.66
            font.pixelSize: Math.max(10, Math.min(root.height * 0.22, 16) * root.labelScale)
            font.weight: Font.Normal
        }

        Controls.Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.active ? root.activeLabelColor : root.labelColor
            opacity: root.active ? 1 : 0.84
            font.pixelSize: Math.max(12, Math.min(root.height * 0.28, 20) * root.labelScale)
            font.weight: Font.Normal
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.dotGlyph && root.active
        width: 24
        height: 24
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: "#F8F8FF"
        opacity: 0.72
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.dotGlyph
        width: 16
        height: 16
        radius: 8
        color: "#F8F8FF"
        opacity: root.active ? 1 : 0.82
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        preventStealing: true
        onClicked: root.triggered()
        onDoubleClicked: {
            // MouseArea suppresses the second onClicked in a rapid same-key
            // pair. Only Shift owns a real double action; every other key
            // must deliver the second tap as ordinary input.
            if (root.doubleTriggerEnabled) root.doubleTriggered();
            else root.triggered();
        }
        onPressed: {
            root.pressed();
            if (root.repeat) {
                repeatDelay.restart();
            }
        }
        onReleased: {
            repeatDelay.stop();
            repeatTimer.stop();
            root.released();
        }
        onCanceled: {
            repeatDelay.stop();
            repeatTimer.stop();
            root.canceled();
        }
        onPressAndHold: root.held()
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
