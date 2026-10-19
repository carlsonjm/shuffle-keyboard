/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick

// How big the card and its keys are on one screen. The card is 44% of the
// screen's height wherever that gives keys at least 16 mm tall, which holds
// on a 13-inch tablet. On a smaller screen it grows until the keys reach
// 16 mm, but never past the size at which twelve and a half square keys still
// fit across, so it never takes room the keys cannot use. A screen that does
// not say how big it is keeps 44%.
QtObject {
    property real screenWidth: 0
    property real screenHeight: 0
    // Logical pixels to the millimetre, as the screen reports it; 0 if it
    // does not.
    property real pixelDensity: 0
    property real totalUnits: 12.5

    readonly property int heightPercent: 44
    readonly property real minimumKeyMm: 16
    readonly property real sideGutter: 10
    readonly property real topStrip: 26

    readonly property real keyGap: Math.max(5, Math.min(10, screenWidth * 0.0062))
    readonly property real outerGap: Math.max(6, Math.min(12, screenWidth * 0.007))
    // The widest a character key can be and still fit across the card.
    readonly property real widthUnit: (screenWidth - sideGutter * 2 - outerGap * 2 + keyGap) / totalUnits - keyGap
    readonly property real chrome: topStrip + keyGap * 3 + outerGap
    readonly property real shareRowHeight: (Math.round(screenHeight * heightPercent / 100) - chrome) / 4
    readonly property real minimumRowHeight: pixelDensity > 0 && isFinite(pixelDensity)
        ? Math.min(minimumKeyMm * pixelDensity, widthUnit) : 0

    readonly property real rowHeight: Math.max(shareRowHeight, minimumRowHeight)
    readonly property real panelHeight: rowHeight > shareRowHeight
        ? Math.round(rowHeight * 4 + chrome) : Math.round(screenHeight * heightPercent / 100)
    // A character key is as wide as it is tall unless a row of them would
    // not fit inside the card, when they all narrow together.
    readonly property real keyUnitWidth: Math.max(1, Math.min(rowHeight, widthUnit))
}
