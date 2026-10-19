/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

import QtQuick
import QtTest
import "../../src/qml"

// The card's height and the keys' size: 44% where that gives keys of 16 mm or
// more, and just enough more for 16 mm keys where it does not.
Item {
    // The Z13 at 150%: 2560 by 1600 on a 13.4-inch 16:10 panel.
    KeySizing { id: z13; screenWidth: 1706.67; screenHeight: 1066.67; pixelDensity: 1066.67 / 180.3 }
    // A Surface Go at 150%: 1920 by 1280 on a 10.5-inch 3:2 panel.
    KeySizing { id: go; screenWidth: 1280; screenHeight: 853.33; pixelDensity: 853.33 / 147.9 }
    // A 10.1-inch tablet at 150%: 1920 by 1200 on a 16:10 panel, 217.6 by 136 mm.
    KeySizing { id: ten; screenWidth: 1280; screenHeight: 800; pixelDensity: (1280 / 217.6 + 800 / 136) / 2 }
    // A screen too narrow for 16 mm keys across: 200 by 150 mm at 4 px/mm.
    KeySizing { id: narrow; screenWidth: 800; screenHeight: 600; pixelDensity: 4 }
    // The same Surface Go, saying nothing about its size.
    KeySizing { id: unknown; screenWidth: 1280; screenHeight: 853.33 }

    TestCase {
        name: "KeySizing"

        function mm(sizing, px) {
            return px / sizing.pixelDensity;
        }

        function test_bigScreenKeepsItsShare() {
            compare(z13.panelHeight, Math.round(1066.67 * 0.44));
            verify(mm(z13, z13.rowHeight) >= 16);
            compare(z13.keyUnitWidth, z13.rowHeight);
        }

        function test_smallScreenGrowsToSixteenMillimetres() {
            fuzzyCompare(mm(go, go.rowHeight), 16, 0.05);
            fuzzyCompare(mm(go, go.keyUnitWidth), 16, 0.05);
            verify(go.panelHeight > Math.round(853.33 * 0.44));
            fuzzyCompare(go.panelHeight / 853.33, 0.50, 0.01);
        }

        // Width-bound just short of 16 mm: the card grows as far as square
        // keys reach across and no further.
        function test_tenInchTabletStopsAtItsWidth() {
            compare(ten.rowHeight, ten.widthUnit);
            compare(ten.keyUnitWidth, ten.rowHeight);
            fuzzyCompare(mm(ten, ten.rowHeight), 15.6, 0.1);
            fuzzyCompare(ten.panelHeight / 800, 0.53, 0.01);
        }

        function test_neverTallerThanSquareKeysFit() {
            compare(narrow.rowHeight, narrow.widthUnit);
            compare(narrow.keyUnitWidth, narrow.rowHeight);
            verify(mm(narrow, narrow.rowHeight) < 16);
        }

        function test_unknownSizeKeepsItsShare() {
            compare(unknown.panelHeight, Math.round(853.33 * 0.44));
            compare(unknown.rowHeight, unknown.shareRowHeight);
        }
    }
}
