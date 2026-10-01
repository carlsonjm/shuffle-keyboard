/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// One key as it is drawn. It handles no touch of its own: the key field
// beneath reads every finger and tells each key whether it is down.
Rectangle {
    id: root

    property string label: ""
    // The small grey character a flick down types, drawn above the label.
    property string secondaryLabel: ""
    property string glyph: ""
    property bool dotGlyph: false
    property bool down: false
    property bool active: false
    property bool locked: false
    property bool emphasised: false
    property bool quiet: false
    property bool wordLabel: false
    // How far a flick down has come, from 0 to 1: the grey character grows
    // into the key's centre as the label fades.
    property real flick: 0

    readonly property color paper: "#F8F8FF"
    readonly property color outline: "#383838"

    // Keys are paper: round keys would read as dots.
    radius: 8
    scale: down ? 0.99 : 1
    color: locked ? paper
         : emphasised ? (down ? "#D9F8F8FF" : "#B3F8F8FF")
         : active ? "#38F8F8FF"
         : down ? outline : "transparent"
    border.width: 1
    border.color: emphasised ? "#B3F8F8FF" : (active ? "#80F8F8FF" : outline)
    opacity: quiet ? 0.12 : 1

    readonly property color ink: (locked || emphasised) ? "#141414" : paper
    readonly property bool hasSecondary: secondaryLabel.length > 0

    Behavior on color { ColorAnimation { duration: 70 } }
    Behavior on scale { NumberAnimation { duration: 55; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 100 } }

    Text {
        id: secondary
        visible: root.hasSecondary
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.12 + root.flick * root.height * 0.24)
        text: root.secondaryLabel
        color: root.ink
        opacity: 0.45 + root.flick * 0.55
        scale: 1 + root.flick * 0.7
        font.pixelSize: Math.max(10, Math.min(root.height * 0.2, 17))
    }

    Text {
        visible: !root.dotGlyph && root.glyph.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.hasSecondary ? Math.round(root.height * 0.1 + root.flick * root.height * 0.22) : 0
        text: root.label
        color: root.ink
        opacity: (root.locked || root.active ? 1 : 0.86) * (1 - root.flick * 0.85)
        font.pixelSize: root.wordLabel ? Math.max(12, Math.min(root.height * 0.24, 20))
                                       : Math.max(14, Math.min(root.height * 0.32, 27))
    }

    KeyGlyph {
        visible: root.glyph.length > 0
        name: root.glyph
        color: root.ink
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.hasSecondary ? Math.round(root.height * 0.1 + root.flick * root.height * 0.22) : 0
        width: Math.round(Math.max(18, Math.min(root.height * 0.36, 34)))
        height: width
        opacity: 0.86 * (1 - root.flick * 0.85)
    }

    // The Tette Dot.
    Rectangle {
        visible: root.dotGlyph
        anchors.centerIn: parent
        width: 16
        height: 16
        radius: 8
        color: root.paper
        opacity: root.down ? 1 : 0.82
    }
}
