/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtQuick.Shapes

// The keys' drawn marks, outlined in Ghost White on a 24-unit grid: Delete's
// arrow with a stem, the arrow keys' chevrons, Emoji's face and Hide's
// keyboard over a chevron.
Shape {
    id: root

    required property string name
    property color color: "#F8F8FF"
    readonly property real unit: width / 24

    preferredRendererType: Shape.CurveRenderer

    readonly property var strokes: ({
        "delete": "M20 12H4.5M10 6.5L4.5 12L10 17.5",
        "left": "M14.5 6.5L9 12L14.5 17.5",
        "right": "M9.5 6.5L15 12L9.5 17.5",
        "up": "M6.5 14.5L12 9L17.5 14.5",
        "down": "M6.5 9.5L12 15L17.5 9.5",
        "emoji": "M21 12A9 9 0 1 1 3 12A9 9 0 1 1 21 12M8.5 14.5C10.3 16.5 13.7 16.5 15.5 14.5",
        "hide": "M5 3.5H19A2 2 0 0 1 21 5.5V12.5A2 2 0 0 1 19 14.5H5A2 2 0 0 1 3 12.5V5.5A2 2 0 0 1 5 3.5M8 11H16M9 18L12 20.5L15 18"
    })
    // Dots drawn filled: Emoji's eyes and the keys on Hide's keyboard.
    readonly property var dots: ({
        "emoji": [[9, 10], [15, 10]],
        "hide": [[6.5, 7], [9.5, 7], [12, 7], [14.5, 7], [17.5, 7]]
    })

    ShapePath {
        strokeColor: root.color
        strokeWidth: Math.max(1.4, root.unit * 1.6)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(root.unit, root.unit)
        PathSvg { path: root.strokes[root.name] || "" }
    }

    ShapePath {
        strokeColor: "transparent"
        fillColor: root.color
        scale: Qt.size(root.unit, root.unit)
        PathSvg {
            path: (root.dots[root.name] || []).map(d => {
                const r = root.name === "emoji" ? 0.9 : 0.75;
                return "M" + (d[0] + r) + " " + d[1] + "A" + r + " " + r + " 0 1 1 " + (d[0] - r) + " " + d[1]
                     + "A" + r + " " + r + " 0 1 1 " + (d[0] + r) + " " + d[1];
            }).join("")
        }
    }
}
